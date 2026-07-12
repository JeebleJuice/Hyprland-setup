#!/usr/bin/env bash
set -euo pipefail

image="${1:-}"
mode="${2:-instant}"
thumb="/tmp/glass-wallpaper-thumb.jpg"

case "${image##*.}" in
    mp4|MP4|webm|WEBM|mkv|MKV|gif|GIF)
        if command -v mpvpaper >/dev/null 2>&1; then
            killall -q mpvpaper swaybg 2>/dev/null || true
            mpvpaper -o "no-audio --loop-playlist" ALL "$image" >/tmp/glass-mpvpaper.log 2>&1 &
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

if [ -z "$image" ] || [ ! -f "$image" ]; then
    notify-send "Wallpaper failed" "Missing image: ${image:-<empty>}"
    exit 1
fi

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
    exit 0
fi

killall -q swaybg 2>/dev/null || true
swaybg -i "$image" -m fill >/tmp/glass-swaybg.log 2>&1 &
