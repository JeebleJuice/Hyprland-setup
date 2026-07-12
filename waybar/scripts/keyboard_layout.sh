#!/bin/bash
set -u

STATE_FILE="$HOME/.cache/waybar-keyboard-layout"

get_keyboard_device() {
    hyprctl devices 2>/dev/null | awk '
        /^Keyboard at / {
            sub(/^Keyboard at /, "")
            sub(/:$/, "")
            print
            exit
        }
    '
}

normalize_layout() {
    case "${1,,}" in
        dk|*dansk*|*danish*|*dk*)
            printf 'DK\n'
            ;;
        us|*us*|*english*|*american*)
            printf 'US\n'
            ;;
        *)
            printf 'US\n'
            ;;
    esac
}

detect_layout() {
    hyprctl devices 2>/dev/null | sed -n 's/^.*active keymap: //p' | head -n1
}

read_layout() {
    layout="$(detect_layout)"
    if [ -n "$layout" ]; then
        printf '%s\n' "$layout"
        return 0
    fi

    if [ -r "$STATE_FILE" ]; then
        cat "$STATE_FILE"
        return 0
    fi

    printf 'US\n'
}

write_layout() {
    mkdir -p "$(dirname "$STATE_FILE")"
    printf '%s\n' "$1" > "$STATE_FILE"
}

toggle_layout() {
    device="$(get_keyboard_device)"
    if [ -n "${device:-}" ] && hyprctl switchxkblayout "$device" next >/dev/null 2>&1; then
        layout="$(normalize_layout "$(detect_layout)")"
        write_layout "$layout"
        printf '%s\n' "$layout"
        return 0
    fi

    if hyprctl switchxkblayout all next >/dev/null 2>&1; then
        layout="$(normalize_layout "$(detect_layout)")"
        write_layout "$layout"
        printf '%s\n' "$layout"
    fi
}

if [ "${1:-}" = "toggle" ]; then
    toggle_layout
    exit 0
fi

layout="$(normalize_layout "$(read_layout)")"
write_layout "$layout"
printf '%s\n' "$layout"
