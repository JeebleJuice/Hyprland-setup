#!/usr/bin/env bash

set -u

required=(
    Hyprland waybar wallust waypaper rofi wlogout swaync hyprlock hypridle
    kitty dolphin kwrite kmail magick jq ffmpeg swaybg grim slurp wl-copy
    brightnessctl playerctl pactl wpctl curl flock kwriteconfig6 dbus-send
)
optional=(
    swww swww-daemon mpvpaper hyprsunset pypr satty hyprpicker cliphist
    protonvpn tailscale nm-connection-editor zenity gdb nm pywalfox
)

missing_required=0

printf 'Required commands:\n'
for command_name in "${required[@]}"; do
    if command -v "$command_name" >/dev/null 2>&1; then
        printf '  OK      %s\n' "$command_name"
    else
        printf '  MISSING %s\n' "$command_name"
        missing_required=1
    fi
done

printf '\nOptional integrations:\n'
for command_name in "${optional[@]}"; do
    if command -v "$command_name" >/dev/null 2>&1; then
        printf '  OK      %s\n' "$command_name"
    else
        printf '  SKIP    %s\n' "$command_name"
    fi
done

printf '\n'
if ((missing_required)); then
    printf 'One or more required commands are missing. See README.md.\n'
    exit 1
fi
printf 'All required commands were found.\n'
