#!/bin/bash

active=$(tuned-adm active 2>/dev/null | sed -n 's/^Current active profile: //p')
[ -z "$active" ] && active="none"
ROFI_THEME="$HOME/.config/rofi/glass-menu.rasi"

choice=$(printf "Lock\nBalanced\nPower saver\nPerformance\nSleep timer\nSuspend now\nHibernate now\nLogout" | rofi -dmenu -theme "$ROFI_THEME" -p "Power: $active")

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

hibernate_now() {
    ~/.config/hypr/scripts/hibernate.sh
}

case "$choice" in
    "Lock")
        ~/.config/hypr/scripts/lock.sh
        ;;
    "Balanced")
        set_profile balanced "Balanced"
        ;;
    "Power saver")
        set_profile powersave "Power saver"
        ;;
    "Performance")
        set_profile throughput-performance "Performance"
        ;;
    "Sleep timer")
        ~/.config/waybar/scripts/sleep_timer_menu.sh
        ;;
    "Suspend now")
        systemctl suspend
        ;;
    "Hibernate now")
        hibernate_now
        ;;
    "Logout")
        hyprctl dispatch exit
        ;;
esac
