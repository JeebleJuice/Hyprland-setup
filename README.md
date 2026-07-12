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
- `waypaper/`
- `nwg-look/`
- `kdeglobals`
- `kwriterc`

## Screenshots

Put preview images in `screenshots/` if you want to document the theme visually.

## Notes

- Wallpaper, Waybar, and theme colors are tied together through `hypr/scripts/wall_color.sh`.
- `waybar/style.css` and `waybar/contrast.css` are generated/updated by the wallpaper workflow, but they are committed here so the theme works out of the box.
- The exported `waypaper/config.ini` and `wlogout/layout` now use home-relative paths or shell expansion instead of a hard-coded username.
- Personal GTK bookmarks are intentionally omitted from the public export.

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

Copy the relevant directories into `~/.config` and ensure the scripts in `hypr/scripts/` are executable.
