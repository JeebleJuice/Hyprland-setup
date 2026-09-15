#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$HOME/.local/state/hyprland-setup/backups"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"

CONFIG_DIRS=(
    hypr waybar wallust kitty rofi wlogout swaync gtk-3.0 gtk-4.0
    qt5ct qt6ct Kvantum waypaper nwg-look autostart
)
CONFIG_FILES=(
    kdeglobals breezerc dolphinrc kiorc kmail2rc kwriterc mimeapps.list
)

backup_target() {
    local target="$1"
    local relative="$2"

    if [ -e "$target" ] || [ -L "$target" ]; then
        mkdir -p "$BACKUP_DIR/$(dirname -- "$relative")"
        cp -a -- "$target" "$BACKUP_DIR/$relative"
    fi
}

mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.themes"

for path in "${CONFIG_DIRS[@]}"; do
    backup_target "$HOME/.config/$path" "config/$path"
done
for path in "${CONFIG_FILES[@]}"; do
    backup_target "$HOME/.config/$path" "config/$path"
done
backup_target "$HOME/.local/share/messageviewer/themes/glassy" \
    "local/share/messageviewer/themes/glassy"
backup_target "$HOME/.local/share/org.kde.syntax-highlighting/themes/Glass Dark.theme" \
    "local/share/org.kde.syntax-highlighting/themes/Glass Dark.theme"
backup_target "$HOME/.themes/Glassy-Originals-Gtk-Purple-Dark" \
    "themes/Glassy-Originals-Gtk-Purple-Dark"

for path in "${CONFIG_DIRS[@]}"; do
    cp -a -- "$REPO_DIR/$path" "$HOME/.config/"
done
for path in "${CONFIG_FILES[@]}"; do
    cp -a -- "$REPO_DIR/$path" "$HOME/.config/$path"
done

cp -a -- "$REPO_DIR/local/share/." "$HOME/.local/share/"
cp -a -- "$REPO_DIR/themes/." "$HOME/.themes/"

chmod +x "$HOME/.config/hypr/scripts/"*.sh
chmod +x "$HOME/.config/waybar/scripts/"*.sh

mkdir -p "$HOME/Pictures/wallpapers"

printf 'Configuration restored.\n'
if [ -d "$BACKUP_DIR" ]; then
    printf 'Previous matching files were backed up to:\n  %s\n' "$BACKUP_DIR"
fi
printf '%s\n' \
    'Next: add wallpapers to ~/Pictures/wallpapers, review monitor/input settings,' \
    'then log out and choose Hyprland from the login screen.'
