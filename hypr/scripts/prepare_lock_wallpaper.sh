#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="$HOME/.cache/hyprlock"
STATE_FILE="$HOME/.cache/current_wall_state"
SOURCE_LINK="$CACHE_DIR/current_wallpaper"
LOCK_WALLPAPER="$CACHE_DIR/current_lock_wallpaper.jpg"

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
            ffmpeg -y -ss 00:00:01.000 -i "$SOURCE" -frames:v 1 -q:v 2 "$LOCK_WALLPAPER" >/dev/null 2>&1
            printf '%s\n' "$LOCK_WALLPAPER"
            exit 0
        fi
        ;;
esac

ln -sfn "$SOURCE" "$LOCK_WALLPAPER"
printf '%s\n' "$LOCK_WALLPAPER"
