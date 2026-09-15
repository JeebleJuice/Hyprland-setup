#!/usr/bin/env bash

set -u

ROFI_THEME="$HOME/.config/rofi/glass-menu.rasi"

notify_wifi() {
    notify-send -a "Wi-Fi" "$1" "${2:-}" 2>/dev/null || true
}

signal_icon() {
    local signal="$1"
    if ((signal >= 75)); then
        printf '󰤨'
    elif ((signal >= 50)); then
        printf '󰤥'
    elif ((signal >= 25)); then
        printf '󰤢'
    else
        printf '󰤟'
    fi
}

saved_connection_for_ssid() {
    local wanted_ssid="$1"
    local connection type saved_ssid

    while IFS= read -r connection; do
        [[ -n "$connection" ]] || continue
        type="$(nmcli -g connection.type connection show "$connection" 2>/dev/null || true)"
        [[ "$type" == "802-11-wireless" ]] || continue
        saved_ssid="$(
            nmcli -g 802-11-wireless.ssid connection show "$connection" 2>/dev/null ||
                true
        )"
        if [[ "$saved_ssid" == "$wanted_ssid" ]]; then
            printf '%s\n' "$connection"
            return 0
        fi
    done < <(nmcli --escape no -g NAME connection show 2>/dev/null)
    return 1
}

connect_to_network() {
    local ssid="$1"
    local security="$2"
    local saved_connection password output

    if saved_connection="$(saved_connection_for_ssid "$ssid")"; then
        if output="$(nmcli connection up id "$saved_connection" 2>&1)"; then
            notify_wifi "Connected" "$ssid"
        else
            notify_wifi "Could not connect to $ssid" "$output"
        fi
        return
    fi

    if [[ -n "$security" && "$security" != "--" ]]; then
        password="$(
            rofi -dmenu -password -theme "$ROFI_THEME" \
                -p "Password for $ssid" </dev/null
        )"
        [[ -n "$password" ]] || return
        if output="$(
            nmcli device wifi connect "$ssid" password "$password" 2>&1
        )"; then
            notify_wifi "Connected" "$ssid"
        else
            notify_wifi "Could not connect to $ssid" "$output"
        fi
    elif output="$(nmcli device wifi connect "$ssid" 2>&1)"; then
        notify_wifi "Connected" "$ssid"
    else
        notify_wifi "Could not connect to $ssid" "$output"
    fi
}

show_wifi_menu() {
    local -a options=()
    local -a actions=()
    local -a network_ssids=()
    local -a network_security=()
    local -A seen=()
    local active_ssid=""
    local line rest in_use ssid signal security icon lock
    local choice_index action network_index

    if [[ "$(nmcli radio wifi)" != "enabled" ]]; then
        options+=("󰤨  Turn Wi-Fi on")
        actions+=("wifi_on")
    else
        active_ssid="$(
            nmcli --escape no -t -f ACTIVE,SSID device wifi |
                sed -n 's/^yes://p' |
                head -1
        )"

        while IFS= read -r line; do
            in_use="${line%%:*}"
            rest="${line#*:}"
            security="${rest##*:}"
            rest="${rest%:*}"
            signal="${rest##*:}"
            ssid="${rest%:*}"

            [[ -n "$ssid" && -z "${seen[$ssid]+x}" ]] || continue
            seen["$ssid"]=1
            [[ "$signal" =~ ^[0-9]+$ ]] || signal=0
            icon="$(signal_icon "$signal")"
            [[ -n "$security" && "$security" != "--" ]] && lock="" || lock=""

            if [[ "$ssid" == "$active_ssid" ]]; then
                options+=("✓  $icon  $ssid  ${signal}%  $lock")
            else
                options+=("   $icon  $ssid  ${signal}%  $lock")
            fi
            network_ssids+=("$ssid")
            network_security+=("$security")
            actions+=("network:$((${#network_ssids[@]} - 1))")
        done < <(
            nmcli --escape no -t -f IN-USE,SSID,SIGNAL,SECURITY \
                device wifi list --rescan yes |
                sort -t: -k3,3nr
        )

        options+=("󰤭  Turn Wi-Fi off")
        actions+=("wifi_off")
    fi

    options+=("󰒓  Edit saved connections")
    actions+=("editor")

    choice_index="$(
        printf '%s\n' "${options[@]}" |
            rofi -dmenu -theme "$ROFI_THEME" -p "Wi-Fi" -format i
    )"
    [[ "$choice_index" =~ ^[0-9]+$ ]] || return
    action="${actions[$choice_index]}"

    case "$action" in
        wifi_on)
            nmcli radio wifi on
            notify_wifi "Wi-Fi enabled"
            ;;
        wifi_off)
            nmcli radio wifi off
            notify_wifi "Wi-Fi disabled"
            ;;
        network:*)
            network_index="${action#network:}"
            ssid="${network_ssids[$network_index]}"
            if [[ "$ssid" == "$active_ssid" ]]; then
                notify_wifi "Already connected" "$ssid"
            else
                connect_to_network "$ssid" "${network_security[$network_index]}"
            fi
            ;;
        editor)
            setsid -f nm-connection-editor >/dev/null 2>&1 || true
            ;;
    esac
}

show_wifi_menu
