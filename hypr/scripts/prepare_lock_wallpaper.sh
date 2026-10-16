#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="$HOME/.cache/hyprlock"
STATE_FILE="$HOME/.cache/current_wall_state"
SOURCE_LINK="$CACHE_DIR/current_wallpaper"
LOCK_WALLPAPER="$CACHE_DIR/current_lock_wallpaper.jpg"
SDDM_WALLPAPER="/var/tmp/glass-sddm-wallpaper.jpg"
LOCK_WALLPAPER_TMP="$CACHE_DIR/.current_lock_wallpaper.$$.tmp.jpg"

trap 'rm -f "$LOCK_WALLPAPER_TMP"' EXIT

mkdir -p "$CACHE_DIR"

SOURCE=""

if [ -e "$SOURCE_LINK" ]; then
    SOURCE="$(readlink -f "$SOURCE_LINK" 2>/dev/null || true)"
fi

if [ -z "$SOURCE" ] && [ -f "$STATE_FILE" ]; then
    SOURCE="$(cat "$STATE_FILE")"
fi

if [ -z "$SOURCE" ] || [ ! -f "$SOURCE" ]; then
    if [ -f "$HOME/.config/waypaper/config.ini" ]; then
        SOURCE="$(grep '^wallpaper =' "$HOME/.config/waypaper/config.ini" | cut -d '=' -f2- | xargs)"
        SOURCE="${SOURCE/#\~/$HOME}"
    fi
fi

if [ -z "$SOURCE" ] || [ ! -f "$SOURCE" ]; then
    exit 1
fi

case "${SOURCE,,}" in
    *.mp4|*.webm|*.mkv|*.gif)
        if command -v ffmpeg >/dev/null 2>&1; then
            ffmpeg -y -ss 00:00:01.000 -i "$SOURCE" -frames:v 1 -q:v 2 \
                "$LOCK_WALLPAPER_TMP" >/dev/null 2>&1
        else
            exit 1
        fi
        ;;
    *)
        cp --reflink=auto "$SOURCE" "$LOCK_WALLPAPER_TMP"
        ;;
esac

# Always replace the prepared lock image itself. Never let FFmpeg write through
# a symlink to the user's original wallpaper.
mv -f "$LOCK_WALLPAPER_TMP" "$LOCK_WALLPAPER"

# SDDM runs before the user session and cannot read an encrypted/private home
# directory. Keep a public, persistent copy of the same prepared still for the
# greeter, replacing it atomically when the wallpaper changes.
cp -L "$LOCK_WALLPAPER" "${SDDM_WALLPAPER}.tmp"
chmod 0644 "${SDDM_WALLPAPER}.tmp"
mv -f "${SDDM_WALLPAPER}.tmp" "$SDDM_WALLPAPER"

printf '%s\n' "$LOCK_WALLPAPER"
