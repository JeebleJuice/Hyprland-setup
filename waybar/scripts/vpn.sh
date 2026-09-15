#!/usr/bin/env bash

set -u

ROFI_THEME="$HOME/.config/rofi/glass-menu.rasi"

notify_vpn() {
    notify-send -a "VPN" "$1" "${2:-}" 2>/dev/null || true
}

refresh_waybar() {
    pkill -RTMIN+8 waybar 2>/dev/null || true
}

proton_status() {
    protonvpn status 2>&1
}

is_signed_in() {
    local account
    account="$(protonvpn info 2>/dev/null | sed -n "s/^Account: '\\(.*\\)'$/\\1/p")"
    [[ -n "$account" && "$account" != "None" ]]
}

tailscale_state() {
    if ! command -v tailscale >/dev/null 2>&1; then
        printf 'Not installed\n'
        return
    fi
    tailscale status --json 2>/dev/null |
        jq -r '.BackendState // "Stopped"' 2>/dev/null ||
        printf 'Stopped\n'
}

networkmanager_available() {
    command -v nmcli >/dev/null 2>&1 && nmcli general status >/dev/null 2>&1
}

load_nm_vpn_profiles() {
    NM_VPN_NAMES=()
    NM_VPN_ACTIVE=()

    networkmanager_available || return

    local name type state
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        type="$(nmcli -g connection.type connection show "$name" 2>/dev/null || true)"
        [[ "$type" == "vpn" || "$type" == "wireguard" ]] || continue

        state="$(nmcli -g GENERAL.STATE connection show "$name" 2>/dev/null || true)"
        NM_VPN_NAMES+=("$name")
        if [[ "$state" == "activated" ]]; then
            NM_VPN_ACTIVE+=("1")
        else
            NM_VPN_ACTIVE+=("0")
        fi
    done < <(nmcli -g NAME connection show 2>/dev/null)
}

print_status() {
    local proton="Not installed"
    local proton_connected=0
    local tailscale
    local tailscale_connected=0
    local home_active=""
    local tooltip
    local i

    if command -v protonvpn >/dev/null 2>&1; then
        local status
        status="$(proton_status)"
        if grep -q '^Status: Connected' <<<"$status"; then
            proton="Connected"
            proton_connected=1
        elif is_signed_in; then
            proton="Disconnected"
        else
            proton="Signed out"
        fi
    fi

    tailscale="$(tailscale_state)"
    [[ "$tailscale" == "Running" ]] && tailscale_connected=1

    load_nm_vpn_profiles
    for i in "${!NM_VPN_NAMES[@]}"; do
        if [[ "${NM_VPN_ACTIVE[$i]}" == "1" ]]; then
            if [[ -n "$home_active" ]]; then
                home_active+=$'\n'
            fi
            home_active+="${NM_VPN_NAMES[$i]}"
        fi
    done
    tooltip=$'VPN connections\nProton: '
    tooltip+="$proton"
    tooltip+=$'\nHome (Tailscale): '
    tooltip+="$tailscale"
    if [[ -n "$home_active" ]]; then
        tooltip+=$'\nImported VPN: Connected ('
        tooltip+="$(paste -sd ', ' <<<"$home_active")"
        tooltip+=")"
    elif ((${#NM_VPN_NAMES[@]})); then
        tooltip+=$'\nImported VPN: Disconnected'
    fi
    tooltip+=$'\n\nLeft-click for options\nRight-click to toggle Proton'

    if ((proton_connected || tailscale_connected)) || [[ -n "$home_active" ]]; then
        jq -cn --arg tooltip "$tooltip" '{
            text: "",
            tooltip: $tooltip,
            class: "connected"
        }'
    elif command -v protonvpn >/dev/null 2>&1 ||
        command -v tailscale >/dev/null 2>&1 ||
        ((${#NM_VPN_NAMES[@]})); then
        jq -cn --arg tooltip "$tooltip" '{
            text: "",
            tooltip: $tooltip,
            class: "disconnected"
        }'
    else
        jq -cn --arg tooltip "$tooltip" '{
            text: "",
            tooltip: $tooltip,
            class: "unavailable"
        }'
    fi
}

toggle_vpn() {
    local status

    if ! command -v protonvpn >/dev/null 2>&1; then
        notify_vpn "Proton VPN is not installed"
        return 1
    fi

    status="$(proton_status)"
    if grep -q '^Status: Connected' <<<"$status"; then
        if protonvpn disconnect >/dev/null 2>&1; then
            notify_vpn "VPN disconnected"
        else
            notify_vpn "Could not disconnect" "Run protonvpn disconnect in a terminal for details."
            return 1
        fi
    elif ! is_signed_in; then
        notify_vpn "Sign in required" "Finish signing in in the terminal that just opened."
        setsid -f kitty \
            --title "Proton VPN sign in" \
            "$HOME/.config/waybar/scripts/proton_signin.sh" \
            >/dev/null 2>&1 || true
    elif protonvpn connect >/dev/null 2>&1; then
        notify_vpn "VPN connected" "Connected to Proton VPN's fastest available server."
    else
        notify_vpn "Could not connect" "Run protonvpn connect in a terminal for details."
        return 1
    fi
}

connect_nm_profile() {
    local name="$1"
    if nmcli connection up id "$name" >/dev/null 2>&1; then
        notify_vpn "Home VPN connected" "$name"
    else
        notify_vpn "Could not connect to home VPN" "$name"
        return 1
    fi
}

disconnect_nm_profile() {
    local name="$1"
    if nmcli connection down id "$name" >/dev/null 2>&1; then
        notify_vpn "Home VPN disconnected" "$name"
    else
        notify_vpn "Could not disconnect home VPN" "$name"
        return 1
    fi
}

import_home_profile() {
    local file type output
    file="$(zenity --file-selection \
        --title="Import home VPN configuration" \
        --file-filter="VPN configurations | *.conf *.ovpn" \
        --file-filter="All files | *" 2>/dev/null || true)"
    [[ -n "$file" ]] || return

    case "${file,,}" in
        *.conf) type="wireguard" ;;
        *.ovpn) type="openvpn" ;;
        *)
            notify_vpn "Unsupported VPN file" "Choose a WireGuard .conf or OpenVPN .ovpn file."
            return 1
            ;;
    esac

    if output="$(nmcli connection import type "$type" file "$file" 2>&1)"; then
        notify_vpn "Home VPN imported" "Click the VPN button again to connect."
    else
        notify_vpn "Could not import home VPN" "$output"
        return 1
    fi
}

show_home_apps() {
    local -a labels=(
        "󰄛  CasaOS"
        "󰄄  Immich"
        "󰿎  Jellyfin"
        "󰑋  Prowlarr"
        "󰎁  Sonarr"
        "󰗚  Readarr"
        "󰎁  Radarr"
        "󰇚  qBittorrent"
    )
    local -a urls=(
        "http://jellyfin-home-server/"
        "http://jellyfin-home-server:2283/"
        "http://jellyfin-home-server:8097/web/"
        "http://jellyfin-home-server:9696/"
        "http://jellyfin-home-server:8989/"
        "http://jellyfin-home-server:8787/"
        "http://jellyfin-home-server:7878/"
        "http://jellyfin-home-server:8080/"
    )
    local choice_index

    choice_index="$(
        printf '%s\n' "${labels[@]}" |
            rofi -dmenu -theme "$ROFI_THEME" -p "Home server" -format i
    )"
    [[ "$choice_index" =~ ^[0-9]+$ ]] || return
    setsid -f xdg-open "${urls[$choice_index]}" >/dev/null 2>&1 || true
}

show_menu() {
    local -a options=()
    local -a actions=()
    local status i choice_index action name
    local ts_state

    ts_state="$(tailscale_state)"
    if [[ "$ts_state" == "Not installed" ]]; then
        options+=("󰌾  Set up Home VPN (Tailscale)")
        actions+=("tailscale_setup")
    elif [[ "$ts_state" == "Running" ]]; then
        options+=("󰌊  Disconnect Home VPN (Tailscale)")
        actions+=("tailscale_down")
        options+=("󰀻  Home server apps")
        actions+=("home_apps")
    else
        options+=("󰖂  Connect Home VPN (Tailscale)")
        actions+=("tailscale_up")
    fi

    if command -v protonvpn >/dev/null 2>&1; then
        status="$(proton_status)"
        if grep -q '^Status: Connected' <<<"$status"; then
            options+=("󰌊  Disconnect Proton VPN")
            actions+=("proton_disconnect")
        elif is_signed_in; then
            options+=("󰖂  Connect Proton VPN (fastest)")
            actions+=("proton_connect")
        else
            options+=("󰌾  Sign in to Proton VPN")
            actions+=("proton_signin")
        fi
    fi

    load_nm_vpn_profiles
    for i in "${!NM_VPN_NAMES[@]}"; do
        if [[ "${NM_VPN_ACTIVE[$i]}" == "1" ]]; then
            options+=("󰌊  Disconnect home: ${NM_VPN_NAMES[$i]}")
            actions+=("home_down:$i")
        else
            options+=("󰖂  Connect home: ${NM_VPN_NAMES[$i]}")
            actions+=("home_up:$i")
        fi
    done

    options+=("󰈙  Import home VPN config (.conf/.ovpn)")
    actions+=("import")
    if command -v nm-connection-editor >/dev/null 2>&1; then
        options+=("󰒓  Edit network connections")
        actions+=("editor")
    fi

    choice_index="$(
        printf '%s\n' "${options[@]}" |
            rofi -dmenu -theme "$ROFI_THEME" -p "VPN" -format i
    )"
    [[ "$choice_index" =~ ^[0-9]+$ ]] || return
    action="${actions[$choice_index]}"

    case "$action" in
        tailscale_setup)
            setsid -f kitty --title "Set up Home VPN" \
                "$HOME/.config/waybar/scripts/setup_home_vpn.sh" \
                >/dev/null 2>&1 || true
            ;;
        tailscale_up)
            if tailscale up >/dev/null 2>&1; then
                notify_vpn "Home VPN connected" "Tailscale is online."
            else
                notify_vpn "Home VPN needs attention" "Run sudo tailscale up in a terminal."
                setsid -f kitty --title "Connect Home VPN" \
                    bash -lc 'sudo tailscale up; read -rp "Press Enter to close..."' \
                    >/dev/null 2>&1 || true
            fi
            ;;
        tailscale_down)
            if tailscale down >/dev/null 2>&1; then
                notify_vpn "Home VPN disconnected" "Tailscale is offline."
            else
                notify_vpn "Could not disconnect Home VPN"
            fi
            ;;
        home_apps)
            show_home_apps
            ;;
        proton_connect)
            if protonvpn connect >/dev/null 2>&1; then
                notify_vpn "Proton VPN connected"
            else
                notify_vpn "Could not connect to Proton VPN"
            fi
            ;;
        proton_disconnect)
            if protonvpn disconnect >/dev/null 2>&1; then
                notify_vpn "Proton VPN disconnected"
            else
                notify_vpn "Could not disconnect Proton VPN"
            fi
            ;;
        proton_signin)
            setsid -f kitty --title "Proton VPN sign in" \
                "$HOME/.config/waybar/scripts/proton_signin.sh" \
                >/dev/null 2>&1 || true
            ;;
        home_up:*)
            i="${action#home_up:}"
            name="${NM_VPN_NAMES[$i]}"
            connect_nm_profile "$name"
            ;;
        home_down:*)
            i="${action#home_down:}"
            name="${NM_VPN_NAMES[$i]}"
            disconnect_nm_profile "$name"
            ;;
        import)
            import_home_profile
            ;;
        editor)
            setsid -f nm-connection-editor >/dev/null 2>&1 || true
            ;;
    esac
    refresh_waybar
}

case "${1:-status}" in
    toggle)
        toggle_vpn
        refresh_waybar
        ;;
    menu)
        show_menu
        ;;
    status)
        print_status
        ;;
    *)
        printf 'Usage: %s [status|toggle|menu]\n' "$0" >&2
        exit 2
        ;;
esac
