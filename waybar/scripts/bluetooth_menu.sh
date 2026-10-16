#!/usr/bin/env bash

ROFI_THEME="$HOME/.config/rofi/glass-menu.rasi"

get_property() {
    busctl --system --json=short get-property \
        org.bluez "$1" "$2" "$3" 2>/dev/null \
        | jq -r '.data' 2>/dev/null
}

bluez_tree=$(busctl --system tree org.bluez --list --no-pager 2>/dev/null) || bluez_tree=""
adapter_path=$(printf '%s\n' "$bluez_tree" | awk '/^\/org\/bluez\/hci[0-9]+$/ { print; exit }')

if [ -z "$adapter_path" ]; then
    notify-send -u critical "Bluetooth" "No Bluetooth controller found"
    exit 1
fi

powered=$(get_property "$adapter_path" org.bluez.Adapter1 Powered)
if [ "$powered" = "true" ]; then
    options="Turn Bluetooth off
Pair new device
Connect paired device
Disconnect connected device
Trust paired device
Remove paired device"
else
    options="Turn Bluetooth on"
fi

choice=$(printf '%s\n' "$options" | rofi -dmenu -theme "$ROFI_THEME" -p "Bluetooth")

pick_device() {
    local property=$1
    local prompt=$2
    local device_path address name entries="" selected

    while IFS= read -r device_path; do
        [ -n "$device_path" ] || continue
        [ "$(get_property "$device_path" org.bluez.Device1 "$property")" = "true" ] || continue
        address=${device_path##*/dev_}
        address=${address//_/:}
        name=$(get_property "$device_path" org.bluez.Device1 Alias)
        [ -n "$name" ] && [ "$name" != "null" ] || name=$address
        entries+="$name  ($address)"$'\t'"$device_path"$'\n'
    done < <(printf '%s\n' "$bluez_tree" | awk '/^\/org\/bluez\/hci[0-9]+\/dev_[[:xdigit:]_]+$/')

    selected=$(printf '%s' "$entries" | sed '/^$/d' | rofi -dmenu -theme "$ROFI_THEME" -p "$prompt")
    printf '%s' "${selected##*$'\t'}"
}

run_action() {
    local success_message=$1
    shift
    if "$@" >/dev/null 2>&1; then
        notify-send "Bluetooth" "$success_message"
    else
        notify-send -u critical "Bluetooth" "Operation failed"
    fi
}

case "$choice" in
    "Turn Bluetooth on")
        run_action "Powered on" busctl --system set-property \
            org.bluez "$adapter_path" org.bluez.Adapter1 Powered b true
        ;;
    "Turn Bluetooth off")
        run_action "Powered off" busctl --system set-property \
            org.bluez "$adapter_path" org.bluez.Adapter1 Powered b false
        ;;
    "Pair new device")
        # BlueDevil keeps an authentication agent alive throughout pairing.
        bluedevil-wizard
        ;;
    "Connect paired device")
        device_path=$(pick_device Paired "Connect")
        [ -n "$device_path" ] && run_action "Device connected" \
            busctl --system call org.bluez "$device_path" org.bluez.Device1 Connect
        ;;
    "Disconnect connected device")
        device_path=$(pick_device Connected "Disconnect")
        [ -n "$device_path" ] && run_action "Device disconnected" \
            busctl --system call org.bluez "$device_path" org.bluez.Device1 Disconnect
        ;;
    "Trust paired device")
        device_path=$(pick_device Paired "Trust")
        [ -n "$device_path" ] && run_action "Device trusted" \
            busctl --system set-property org.bluez "$device_path" org.bluez.Device1 Trusted b true
        ;;
    "Remove paired device")
        device_path=$(pick_device Paired "Remove")
        if [ -n "$device_path" ]; then
            device_adapter=${device_path%/dev_*}
            run_action "Device removed" busctl --system call \
                org.bluez "$device_adapter" org.bluez.Adapter1 RemoveDevice o "$device_path"
        fi
        ;;
esac
