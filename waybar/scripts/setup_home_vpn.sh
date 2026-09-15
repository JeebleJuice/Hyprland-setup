#!/usr/bin/env bash

set -u

SERVER="${HOME_VPN_SERVER:-jeeblejuice@192.168.1.100}"
SERVER_ADDRESS="${SERVER#*@}"
INSTALL_URL="https://tailscale.com/install.sh"

pause() {
    printf '\n'
    read -r -p "Press Enter to close..." _
}

fail() {
    printf '\nHome VPN setup stopped: %s\n' "$1" >&2
    pause
    exit 1
}

printf '\033[1;36mHome VPN setup for Jellyfin\033[0m\n\n'
printf '%s\n' \
    "This will install Tailscale on:" \
    "  1. This Fedora laptop" \
    "  2. The Ubuntu home server at $SERVER_ADDRESS" \
    "" \
    "Passwords stay inside this terminal. You will also receive a web login" \
    "link for each device; use the same Tailscale account for both."
printf '\n'
read -r -p "Continue? [Y/n] " answer
case "${answer:-y}" in
    y|Y|yes|YES) ;;
    *) exit 0 ;;
esac

installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT

printf '\n\033[1mDownloading the official Tailscale installer...\033[0m\n'
curl -fsSL "$INSTALL_URL" -o "$installer" ||
    fail "Could not download the Tailscale installer."

if ! command -v tailscale >/dev/null 2>&1; then
    printf '\n\033[1mInstalling Tailscale on Fedora (sudo password required)...\033[0m\n'
    sudo sh "$installer" || fail "Fedora installation failed."
fi

sudo systemctl enable --now tailscaled ||
    fail "Could not start tailscaled on Fedora."
sudo tailscale set --operator="$USER" 2>/dev/null || true

printf '\n\033[1mConnecting Fedora to your private network...\033[0m\n'
printf 'Open the login URL shown below and finish signing in.\n\n'
tailscale up --hostname=fedora-laptop ||
    sudo tailscale up --hostname=fedora-laptop ||
    fail "Fedora could not join Tailscale."

printf '\n\033[1mInstalling and connecting the Ubuntu home server...\033[0m\n'
printf '%s\n' \
    "SSH will ask for the Ubuntu account password." \
    "Ubuntu sudo may ask for it once more. Then open the second login URL."
printf '\n'

ssh -t "$SERVER" \
    'set -e
    if ! command -v tailscale >/dev/null 2>&1; then
        curl -fsSL https://tailscale.com/install.sh | sh
    fi
    sudo systemctl enable --now tailscaled
    sudo tailscale up --hostname=jellyfin-home-server
    printf "\nHome server Tailscale address: "
    tailscale ip -4
    printf "\nJellyfin listeners:\n"
    sudo ss -ltnp | grep -E ":(80|443|8096|8920)[[:space:]]" || true
    if command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -q "^Status: active"; then
        sudo ufw allow in on tailscale0 to any port 8097 proto tcp
    fi' ||
    fail "Could not finish setup on the Ubuntu server."

printf '\n\033[1;32mHome VPN setup complete.\033[0m\n'
printf '%s\n' \
    "The Waybar VPN button can now connect or disconnect Tailscale." \
    "Use the home server Tailscale address shown above for Jellyfin," \
    "for this server: http://TAILSCALE-IP:8097"

pkill -RTMIN+8 waybar 2>/dev/null || true
pause
