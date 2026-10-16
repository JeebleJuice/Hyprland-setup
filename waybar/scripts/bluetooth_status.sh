#!/usr/bin/env bash

# Query BlueZ over D-Bus instead of repeatedly starting bluetoothctl. BlueZ
# 5.87 can abort bluetoothctl when a device changes state during a one-shot
# query, which produces a misleading desktop crash notification.
get_property() {
    busctl --system --json=short get-property \
        org.bluez "$1" "$2" "$3" 2>/dev/null \
        | jq -r '.data' 2>/dev/null
}

if ! bluez_tree=$(busctl --system tree org.bluez --list --no-pager 2>/dev/null); then
    jq -cn '{text: "", tooltip: "No Bluetooth controller", class: "off"}'
    exit
fi

mapfile -t adapters < <(printf '%s\n' "$bluez_tree" | awk '/^\/org\/bluez\/hci[0-9]+$/')
if [ "${#adapters[@]}" -eq 0 ]; then
    jq -cn '{text: "", tooltip: "No Bluetooth controller", class: "off"}'
    exit
fi

powered=false
for adapter in "${adapters[@]}"; do
    if [ "$(get_property "$adapter" org.bluez.Adapter1 Powered)" = "true" ]; then
        powered=true
        break
    fi
done

if [ "$powered" != "true" ]; then
    jq -cn '{text: "", tooltip: "Bluetooth is off", class: "off"}'
    exit
fi

mapfile -t device_paths < <(printf '%s\n' "$bluez_tree" | awk '/^\/org\/bluez\/hci[0-9]+\/dev_[[:xdigit:]_]+$/')
connected=()
for device_path in "${device_paths[@]}"; do
    if [ "$(get_property "$device_path" org.bluez.Device1 Connected)" = "true" ]; then
        connected+=("$device_path")
    fi
done

count=${#connected[@]}
if [ "$count" -eq 0 ]; then
    jq -cn '{text: "", tooltip: "Bluetooth is on\nNo connected devices", class: "on"}'
    exit
fi

tooltip="Bluetooth: $count connected"
display_battery=""

for device_path in "${connected[@]}"; do
    address=${device_path##*/dev_}
    address=${address//_/:}
    name=$(get_property "$device_path" org.bluez.Device1 Alias)
    [ -n "$name" ] && [ "$name" != "null" ] || name=$address
    battery_file="/sys/class/power_supply/ps-controller-battery-${address,,}/capacity"

    tooltip+=$'\n\n'
    if [ -r "$battery_file" ]; then
        battery=$(<"$battery_file")
        tooltip+="$name   $battery%"
        [ -z "$display_battery" ] && display_battery=$battery
    else
        tooltip+="$name"
    fi
done

if [ -n "$display_battery" ]; then
    text="   $display_battery%"
else
    text=""
fi

jq -cn \
    --arg text "$text" \
    --arg tooltip "$tooltip" \
    '{text: $text, tooltip: $tooltip, class: "connected"}'
