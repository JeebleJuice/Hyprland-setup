#!/bin/bash

if pidof hyprlock >/dev/null 2>&1; then
    exit 0
fi

if ! ~/.config/hypr/scripts/prepare_lock_wallpaper.sh >/dev/null 2>&1; then
    notify-send "Lock screen" "Could not prepare a lock wallpaper. Falling back to the current wallpaper source."
fi

if command -v hyprlock >/dev/null 2>&1; then
    exec hyprlock
fi

loginctl lock-session
