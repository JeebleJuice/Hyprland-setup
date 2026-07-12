#!/bin/bash

STATE_FILE="$HOME/.cache/current_wall_state"
WAYPAPER_CONFIG="$HOME/.config/waypaper/config.ini"

if [ -f "$STATE_FILE" ]; then
    WALLPAPER=$(cat "$STATE_FILE")
elif [ -f "$WAYPAPER_CONFIG" ]; then
    WALLPAPER=$(grep '^wallpaper =' "$WAYPAPER_CONFIG" | cut -d '=' -f2- | xargs)
    WALLPAPER="${WALLPAPER/#\~/$HOME}"
fi

if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
    WALLPAPER=$(find "$HOME/Pictures/wallpapers" -maxdepth 1 -type f \( \
        -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
    \) | sort | head -n 1)
fi

if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
    notify-send "Wallpaper restore failed" "No static wallpaper found in ~/Pictures/wallpapers"
    exit 1
fi

mkdir -p "$HOME/.cache/hyprlock"
ln -sfn "$WALLPAPER" "$HOME/.cache/hyprlock/current_wallpaper"

~/.config/hypr/scripts/apply_wallpaper.sh "$WALLPAPER"
