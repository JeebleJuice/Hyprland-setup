#!/usr/bin/env bash

set -u

clear
printf 'Proton VPN sign in\n\n'
read -r -p 'Proton username or email: ' username

if [[ -z "$username" ]]; then
    printf '\nNo username entered.\n'
    read -r -p 'Press Enter to close...'
    exit 1
fi

printf '\n'
if protonvpn signin "$username"; then
    notify-send -a "Proton VPN" "Sign-in complete" "Click the Waybar VPN button to connect." 2>/dev/null || true
    printf '\nSign-in complete. You can close this window.\n'
else
    printf '\nSign-in failed. The error is shown above.\n'
fi

printf '\n'
read -r -p 'Press Enter to close...'
