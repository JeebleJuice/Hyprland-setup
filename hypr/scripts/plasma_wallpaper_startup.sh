#!/usr/bin/env bash

# Plasma's desktop containment is created asynchronously during login. Give it
# a moment before restoring the wallpaper shared with the Hyprland session.
sleep 3
exec "$HOME/.config/hypr/scripts/restore_wallpaper.sh"
