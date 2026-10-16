#!/usr/bin/env bash

set -euo pipefail

if ((EUID != 0)); then
    printf 'Run this optional installer with sudo: sudo ./install-system.sh\n' >&2
    exit 1
fi

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/var/lib/hyprland-setup/backups/$(date +%Y%m%d-%H%M%S)"

install_with_backup() {
    local source="$1"
    local target="$2"

    if [ -e "$target" ] || [ -L "$target" ]; then
        mkdir -p "$BACKUP_DIR$(dirname -- "$target")"
        cp -a -- "$target" "$BACKUP_DIR$target"
    fi
    install -Dm644 -- "$source" "$target"
}

install_with_backup \
    "$REPO_DIR/system/sddm.conf.d/10-theme.conf" \
    "/etc/sddm.conf.d/10-theme.conf"
install_with_backup \
    "$REPO_DIR/system/sddm/breeze-theme.conf.user" \
    "/usr/share/sddm/themes/breeze/theme.conf.user"
install_with_backup \
    "$REPO_DIR/system/modprobe.d/99-btusb-no-autosuspend.conf" \
    "/etc/modprobe.d/99-btusb-no-autosuspend.conf"

printf 'Installed SDDM theme settings and the btusb autosuspend override.\n'
printf 'Backups of replaced files, when present: %s\n' "$BACKUP_DIR"
printf 'Reboot to guarantee that the btusb module option is active.\n'
