#!/usr/bin/env bash
set -euo pipefail

image="${1:-}"
mode="${2:-instant}"
thumb="/tmp/glass-wallpaper-thumb.jpg"
mpvpaper_socket="${XDG_RUNTIME_DIR:-/tmp}/glass-mpvpaper.sock"

if [ -z "$image" ] || [ ! -f "$image" ]; then
    notify-send "Wallpaper failed" "Missing image: ${image:-<empty>}"
    exit 1
fi

# Refresh both Hyprlock's image and the login-screen copy whenever the desktop
# wallpaper changes.
"$HOME/.config/hypr/scripts/prepare_lock_wallpaper.sh" >/dev/null 2>&1 || true

ext="${image##*.}"

# Plasma owns its desktop background surface, so wlroots wallpaper clients such
# as mpvpaper, swww and swaybg cannot be used there. Use Plasma's wallpaper
# packages instead while keeping this script as the common entry point.
if [[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]] || [ -n "${KDE_FULL_SESSION:-}" ]; then
    case "$ext" in
        mp4|MP4|webm|WEBM|mkv|MKV|gif|GIF)
            plugin="luisbocanegra.smart.video.wallpaper.reborn"
            plugin_dir="$HOME/.local/share/plasma/wallpapers/$plugin"

            if [ ! -d "$plugin_dir" ]; then
                notify-send "Wallpaper failed" "The Plasma video wallpaper plugin is not installed."
                exit 1
            fi

            video_url="file://$(realpath "$image")"
            video_json=$(jq -cn --arg filename "$video_url" \
                '[{filename:$filename,enabled:true,duration:0,customDuration:0,playbackRate:0,alternativePlaybackRate:0,loop:true}]')
            video_config=$(jq -Rn --arg value "$video_json" '$value')
            # Smart Video Wallpaper uses PauseMode=3 for "Never". Value 0
            # pauses playback whenever any maximized/full-screen window exists.
            # Recreate the wallpaper item after storing its configuration. This
            # clears the plugin's non-persistent manual pause override and makes
            # the new MediaPlayer start with the requested source immediately.
            plasma_script="var ds=desktops(); for (var i=0; i<ds.length; ++i) { var d=ds[i]; d.wallpaperPlugin=\"org.kde.image\"; d.currentConfigGroup=[\"Wallpaper\",\"$plugin\",\"General\"]; d.writeConfig(\"VideoUrls\",$video_config); d.writeConfig(\"MuteMode\",5); d.writeConfig(\"PauseMode\",3); d.writeConfig(\"ResumeLastVideo\",false); d.wallpaperPlugin=\"$plugin\"; }"

            qdbus org.kde.plasmashell /PlasmaShell \
                org.kde.PlasmaShell.evaluateScript "$plasma_script" >/dev/null
            ;;
        *)
            plasma-apply-wallpaperimage "$image" >/dev/null
            ;;
    esac
    exit 0
fi

case "${image##*.}" in
    mp4|MP4|webm|WEBM|mkv|MKV|gif|GIF)
        if command -v mpvpaper >/dev/null 2>&1; then
            # Reuse the active player when moving between animated wallpapers.
            # This keeps its layer visible while mpv replaces the media, rather
            # than briefly exposing Swww's most recent static wallpaper.
            if pgrep -x mpvpaper >/dev/null 2>&1 \
                && [ -S "$mpvpaper_socket" ] \
                && command -v socat >/dev/null 2>&1; then
                if jq -cn --arg path "$image" \
                    '{command:["loadfile",$path,"replace"]}' \
                    | socat - "UNIX-CONNECT:$mpvpaper_socket" >/dev/null 2>&1; then
                    exit 0
                fi
            fi

            killall -q mpvpaper 2>/dev/null || true
            rm -f "$mpvpaper_socket"
            # Do not inherit mpv.conf: display-resampling and interpolation are
            # wasteful for a continuously running animated wallpaper. Limiting
            # the source to 15 fps keeps the effect smooth while substantially
            # reducing compositor and decoder load.
            mpvpaper -o "config=no no-audio loop-playlist vf=fps=15 interpolation=no video-sync=audio input-ipc-server=$mpvpaper_socket" \
                ALL "$image" >/tmp/glass-mpvpaper.log 2>&1 &

            # Do not remove any fallback surface until mpvpaper is accepting
            # commands and its new background layer has been created.
            for _ in {1..20}; do
                [ -S "$mpvpaper_socket" ] && break
                sleep 0.05
            done
            killall -q swaybg 2>/dev/null || true
            exit 0
        fi

        if command -v ffmpeg >/dev/null 2>&1; then
            notify-send "Wallpaper fallback" "mpvpaper is missing, so $image will be shown as a still frame. Install mpvpaper for live video wallpapers."
            ffmpeg -y -i "$image" -ss 00:00:01.000 -vframes 1 "$thumb" -loglevel quiet
            image="$thumb"
        else
            notify-send "Wallpaper failed" "Video wallpapers need mpvpaper or ffmpeg."
            exit 1
        fi
        ;;
esac

if command -v swww >/dev/null 2>&1 && command -v swww-daemon >/dev/null 2>&1; then
    if ! pgrep -x swww-daemon >/dev/null 2>&1; then
        swww-daemon >/tmp/glass-swww.log 2>&1 &
        sleep 0.2
    fi

    if [ "$mode" = "animate" ]; then
        swww img "$image" --transition-type wipe --transition-step 20 --transition-fps 60
    else
        swww img "$image"
    fi
    killall -q mpvpaper swaybg 2>/dev/null || true
    rm -f "$mpvpaper_socket"
    exit 0
fi

killall -q swaybg 2>/dev/null || true
swaybg -i "$image" -m fill >/tmp/glass-swaybg.log 2>&1 &
