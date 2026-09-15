#!/bin/bash

active=$(tuned-adm active 2>/dev/null | sed -n 's/^Current active profile: //p')
[ -z "$active" ] && active="none"
ROFI_THEME="$HOME/.config/rofi/glass-menu.rasi"

choice=$(printf "Balanced\nPerformance\nPower saver\nSleep timer" | rofi -dmenu -theme "$ROFI_THEME" -p "Power: $active")

set_profile() {
    profile="$1"
    if tuned-adm profile "$profile" >/tmp/waybar-power.log 2>&1; then
        notify-send "Power profile" "$2"
    else
        if command -v pkexec >/dev/null 2>&1; then
            pkexec systemctl start tuned && tuned-adm profile "$profile" >/tmp/waybar-power.log 2>&1
            notify-send "Power profile" "$2"
        else
            notify-send "Power profile failed" "TuneD is not running. Try: sudo systemctl enable --now tuned"
        fi
    fi
}

case "$choice" in
    "Balanced")
        set_profile balanced "Balanced"
        ;;
    "Performance")
        set_profile throughput-performance "Performance"
        ;;
    "Power saver")
        set_profile powersave "Power saver"
        ;;
    "Sleep timer")
        ~/.config/waybar/scripts/sleep_timer_menu.sh
        ;;
esac
