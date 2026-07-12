#!/bin/bash

powered=$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered/ {print $2}')
ROFI_THEME="$HOME/.config/rofi/glass-menu.rasi"

if [ "$powered" = "yes" ]; then
    options="Turn Bluetooth off
Scan for devices
Connect paired device
Disconnect connected device
Trust paired device
Remove paired device"
else
    options="Turn Bluetooth on"
fi

choice=$(printf "%s\n" "$options" | rofi -dmenu -theme "$ROFI_THEME" -p "Bluetooth")

pick_device() {
    bluetoothctl devices "$1" 2>/dev/null \
        | sed 's/^Device //' \
        | rofi -dmenu -theme "$ROFI_THEME" -p "$2" \
        | awk '{print $1}'
}

case "$choice" in
    "Turn Bluetooth on")
        bluetoothctl power on
        notify-send "Bluetooth" "Powered on"
        ;;
    "Turn Bluetooth off")
        bluetoothctl power off
        notify-send "Bluetooth" "Powered off"
        ;;
    "Scan for devices")
        bluetoothctl scan on
        notify-send "Bluetooth" "Scanning for devices"
        ;;
    "Connect paired device")
        mac=$(pick_device Paired "Connect")
        [ -n "$mac" ] && bluetoothctl connect "$mac"
        ;;
    "Disconnect connected device")
        mac=$(pick_device Connected "Disconnect")
        [ -n "$mac" ] && bluetoothctl disconnect "$mac"
        ;;
    "Trust paired device")
        mac=$(pick_device Paired "Trust")
        [ -n "$mac" ] && bluetoothctl trust "$mac"
        ;;
    "Remove paired device")
        mac=$(pick_device Paired "Remove")
        [ -n "$mac" ] && bluetoothctl remove "$mac"
        ;;
esac
