#!/bin/bash

THEME="Glassy-Originals-Gtk-Purple-Dark"
ICON_THEME="candy-icons"
CURSOR_THEME="Bibata-Modern-Classic"
FONT="Adwaita Sans 11"

gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme "$THEME"
gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME"
gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME"

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

for settings in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    cat > "$settings" <<EOF
[Settings]
gtk-theme-name=$THEME
gtk-icon-theme-name=$ICON_THEME
gtk-font-name=$FONT
gtk-cursor-theme-name=$CURSOR_THEME
gtk-cursor-theme-size=23
gtk-application-prefer-dark-theme=1
EOF
done
