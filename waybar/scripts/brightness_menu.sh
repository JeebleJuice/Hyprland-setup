#!/bin/bash

DEVICE="intel_backlight"
current=$(brightnessctl -d "$DEVICE" info | awk -F'[()]' '/Current brightness/ {print $2}')
ROFI_THEME="$HOME/.config/rofi/glass-menu.rasi"

choice=$(printf "Increase +10%%\nDecrease -10%%\n10%%\n25%%\n50%%\n75%%\n100%%\nCustom..." | rofi -dmenu -theme "$ROFI_THEME" -p "Brightness $current")

case "$choice" in
    "Increase +10%")
        brightnessctl -d "$DEVICE" set +10%
        ;;
    "Decrease -10%")
        brightnessctl -d "$DEVICE" set 10%-
        ;;
    10%|25%|50%|75%|100%)
        brightnessctl -d "$DEVICE" set "$choice"
        ;;
    "Custom...")
        value=$(printf "" | rofi -dmenu -theme "$ROFI_THEME" -p "Brightness percent")
        case "$value" in
            ''|*[!0-9]*)
                exit 0
                ;;
            *)
                if [ "$value" -ge 1 ] && [ "$value" -le 100 ]; then
                    brightnessctl -d "$DEVICE" set "$value%"
                fi
                ;;
        esac
        ;;
esac
