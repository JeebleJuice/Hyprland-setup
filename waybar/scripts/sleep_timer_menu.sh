#!/bin/bash

CONFIG="$HOME/.config/hypr/hypridle.conf"
STATE="$HOME/.cache/glass-sleep-timeout"
ROFI_THEME="$HOME/.config/rofi/glass-menu.rasi"

choice=$(printf "Never\n5 minutes\n10 minutes\n15 minutes\n30 minutes\n60 minutes" | rofi -dmenu -theme "$ROFI_THEME" -p "Sleep timer")

case "$choice" in
    "Never")
        timeout=0
        label="Never"
        ;;
    "5 minutes")
        timeout=300
        label="5 minutes"
        ;;
    "10 minutes")
        timeout=600
        label="10 minutes"
        ;;
    "15 minutes")
        timeout=900
        label="15 minutes"
        ;;
    "30 minutes")
        timeout=1800
        label="30 minutes"
        ;;
    "60 minutes")
        timeout=3600
        label="60 minutes"
        ;;
    *)
        exit 0
        ;;
esac

mkdir -p "$HOME/.config/hypr"
printf "%s\n" "$timeout" > "$STATE"

cat > "$CONFIG" <<EOF
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
    timeout = 300
    on-timeout = loginctl lock-session
}
EOF

if [ "$timeout" -gt 0 ]; then
    cat >> "$CONFIG" <<EOF

listener {
    timeout = $timeout
    on-timeout = systemctl suspend
}
EOF
fi

pkill hypridle 2>/dev/null
hypridle >/tmp/hypridle.log 2>&1 &
notify-send "Sleep timer" "$label"
