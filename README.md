# Hyprland Config

This directory is a publishable copy of my Hyprland setup and the related desktop theming/config files.

## Included

- `hypr/`
- `waybar/`
- `wallust/`
- `kitty/`
- `rofi/`
- `wlogout/`
- `swaync/`
- `gtk-3.0/`
- `gtk-4.0/`
- `qt5ct/`
- `qt6ct/`
- `Kvantum/`
- `waypaper/`
- `nwg-look/`
- `autostart/`
- `kdeglobals`
- `breezerc`
- `dolphinrc`
- `kiorc`
- `kmail2rc` (appearance and layout only; no accounts or mail)
- `kwriterc`
- `mimeapps.list` (default application associations)
- `local/share/messageviewer/themes/glassy/` (KMail theme)
- `local/share/org.kde.syntax-highlighting/themes/Glass Dark.theme` (KWrite theme)

## Screenshots

Put preview images in `screenshots/` if you want to document the theme visually.

## Notes

- Wallpaper, Waybar, and theme colors are tied together through `hypr/scripts/wall_color.sh`.
- `waybar/style.css` and `waybar/contrast.css` are generated/updated by the wallpaper workflow, but they are committed here so the theme works out of the box.
- The exported `waypaper/config.ini` and `wlogout/layout` now use home-relative paths or shell expansion instead of a hard-coded username.
- Personal GTK bookmarks are intentionally omitted from the public export.
- KMail accounts, identities, transport settings, passwords, Akonadi state,
  remote-content exceptions, and cached messages are intentionally omitted.
- Machine/private VPN helpers and NetworkManager connection profiles are
  intentionally omitted.
- `waypaper/config.ini` expects wallpapers in `~/Pictures/wallpapers`; wallpaper
  files are not included.

## Main shortcuts

- `SUPER + W` cycles wallpaper and regenerates colors.
- `SUPER + Q` Close focused tile.
- `SUPER + L` locks the screen.
- `SUPER + Shift + C` opens the color picker.
- `SUPER + Shift + B` restarts Waybar.
- `SUPER + Shift + K` opens KWrite.
- `SUPER + Print` takes a region screenshot and opens Satty.
- `SUPER + Shift + Print` saves a full screenshot.
- `SUPER + Ctrl + Print` copies a region screenshot to the clipboard.

## Applying

Install the applications and themes first. From the repository root, copy the
configuration into place:

```bash
mkdir -p ~/.config ~/.local/share

for path in \
  hypr waybar wallust kitty rofi wlogout swaync gtk-3.0 gtk-4.0 \
  qt5ct qt6ct Kvantum waypaper nwg-look autostart \
  kdeglobals breezerc dolphinrc kiorc kmail2rc kwriterc mimeapps.list; do
    cp -a "$path" ~/.config/
done

cp -a local/share/. ~/.local/share/
chmod +x ~/.config/hypr/scripts/*.sh ~/.config/waybar/scripts/*.sh
```

Review `hypr/conf/monitors/`, input-device names, GPU environment settings, and
weather/location settings for the new machine before logging in.

### KMail accounts

The repository restores KMail's glass theme, reader colors, sorting, and window
layout. Add mail accounts again through KMail on the new machine so passwords
stay in its new KWallet. For a full private migration, use KDE PIM Data Exporter
separately rather than committing `emailidentities`, `mailtransports`, Akonadi
resource files, or mail data to this repository.
