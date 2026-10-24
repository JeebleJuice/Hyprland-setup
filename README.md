# Hyprland setup

This repository is the portable, public copy of the Hyprland desktop used on
the source Fedora system. It contains configuration and theme assets, not
personal documents, wallpaper files, mail, passwords, or VPN keys.

The restore target is Fedora Workstation. The current export was audited on
Fedora 44, so package names may need small adjustments on later Fedora
releases.

## What is restored

- Native Hyprland 0.55+ Lua configuration, plus the previous Hyprlang tree as
  a fallback; both cover keybindings, animations, window rules, blur, idle
  locking, screenshots, wallpaper shortcuts, and three-finger horizontal
  workspace swiping
- Waybar layout, CSS, menus, illustrated terminal weather, brightness and
  power controls, VPN, Bluetooth/controller battery, resource telemetry, and
  a live microphone meter
- Static, animated, and video wallpaper handling
- Wallpaper-derived colors for Waybar, Wlogout, Rofi, SwayNC, Kitty,
  Hyprland borders, KDE/Qt palettes, Kvantum, GTK, KMail, and optional
  Obsidian highlights
- Kitty, Rofi, Wlogout, SwayNC, Waypaper, Qt5ct, Qt6ct, Kvantum, NWG Look,
  GTK 3/4, and KDE appearance settings
- Dolphin, Ark, Gwenview, Okular, Spectacle, KOrganizer, Konsole, and Plasma
  System Monitor preferences; KWrite syntax styling; KMail appearance and
  message-viewer theme; and default application associations
- The source System Monitor pages and the custom pie/line sensor faces that
  follow the current wallpaper accent
- The customized `Glassy-Originals-Gtk-Purple-Dark` GTK theme
- KDE autostart and `Meta + W` support for restoring/cycling the same
  wallpaper in Plasma
- Pyprland scratchpad and the user portal service override used by the active
  Hyprland session
- An optional root installer for SDDM's shared wallpaper and the Intel AX201
  Bluetooth HID autosuspend workaround

The active compositor configuration is `~/.config/hypr/hyprland.lua`.
`hyprland.conf` and its `conf/` includes remain available as a fallback for
systems without Lua configuration support.

The dynamic wallpaper flow is:

1. `SUPER + W` selects the next file in `~/Pictures/wallpapers`.
2. `apply_wallpaper.sh` uses a low-overhead mpvpaper profile for video, swww
   for transitioned static images, or swaybg as the static fallback.
3. `wall_color.sh` samples the image and runs Wallust on first use. Its palette
   and representative video frame are cached for later switches.
4. Wallust writes the base palettes.
5. The script chooses readable foreground colors, creates a three-color
   Hyprland border, transitions Waybar's accent, recolors Kvantum and GTK,
   updates KDE/KMail/Obsidian, and reloads running components where supported.

Waypaper provides the graphical wallpaper picker and stores the current
wallpaper. The repository does not use Hyprpaper.

## Deliberately not included

These must be recreated or supplied separately:

- Wallpaper images and videos
- KMail and KOrganizer accounts, identities, calendars, messages, Akonadi
  data, passwords, and KWallet
- NetworkManager connection profiles
- WireGuard private keys, OpenVPN credentials, Proton credentials, Tailscale
  authentication, and other tokens
- Browser profiles and personal Obsidian vaults
- Additional machine profiles beyond the documented source-laptop display and
  touchpad settings

The VPN scripts are included. They discover imported NetworkManager VPNs and
support Proton VPN, Tailscale, WireGuard/OpenVPN import, and the configured
home-server shortcuts. No credential material is committed.

## Fresh Fedora restore

### 1. Install the system packages

Enable the Hyprland COPR used by the source system:

~~~bash
sudo dnf install dnf-plugins-core git
sudo dnf copr enable lionheartp/Hyprland
~~~

Install the main Fedora packages:

~~~bash
sudo dnf install   hyprland hyprlock hypridle hyprsunset waybar rofi wlogout   SwayNotificationCenter kitty dolphin kwrite kmail kcalc korganizer konsole   ark gwenview okular spectacle plasma-systemmonitor plasma-discover-notifier   pam-kwallet bluedevil kvantum kvantum-qt5 breeze-icon-theme ImageMagick   ffmpeg-free swaybg jq zenity socat bluez grim slurp wl-clipboard   brightnessctl playerctl pulseaudio-utils wireplumber cliphist hyprpicker   NetworkManager nm-connection-editor kf6-kconfig polkit-kde binutils gdb   util-linux-core curl rsync cargo pipx google-noto-sans-fonts   abattis-cantarell-fonts fontawesome-6-free-fonts
~~~

If a package name changes on a newer Fedora release, use
`dnf search NAME` or `dnf provides '*/COMMAND'` rather than removing the
corresponding feature from the configuration.

Install the user-level tools:

~~~bash
pipx ensurepath
pipx install waypaper
pipx install pyprland
cargo install wallust
cargo install satty
~~~

Log out and back in after `pipx ensurepath`, or make sure
`~/.local/bin` is on `PATH`.

The browser and Obsidian shortcuts use their Flathub application IDs:

~~~bash
flatpak install flathub app.zen_browser.zen md.obsidian.Obsidian
~~~

Optional wallpaper backends:

- swww gives animated transitions for still images.
- mpvpaper is needed for live video wallpapers. Without it, the scripts use a
  still video frame when ffmpeg is available.
- swaybg is the guaranteed static fallback.

Use each project's current upstream installation instructions:
[Waypaper](https://github.com/anufrievroman/waypaper),
[Wallust](https://codeberg.org/explosion-mental/wallust),
[Pyprland](https://hyprland-community.github.io/pyprland/),
[swww](https://github.com/LGFae/swww), and
[mpvpaper](https://github.com/GhostNaN/mpvpaper).

Install **JetBrainsMono Nerd Font** from
[Nerd Fonts](https://www.nerdfonts.com/font-downloads). Waybar and Kitty use
its glyphs. The source setup also uses the **Bibata Modern Classic** cursor and
the **Candy Icons** theme; install them under `~/.icons/Bibata-Modern-Classic`
and `~/.local/share/icons/candy-icons`, or change the names in
`hypr/hyprland.lua` and `hypr/scripts/gtk.sh`. Noto Sans and Cantarell come
from the Fedora packages above.

### 2. Clone and apply the repository

~~~bash
git clone https://github.com/JeebleJuice/Hyprland-setup.git
cd Hyprland-setup
chmod +x restore.sh check-dependencies.sh
./restore.sh
~~~

`restore.sh` backs up matching existing configuration under
`~/.local/state/hyprland-setup/backups/`, installs the repository contents,
fixes script permissions, and creates `~/Pictures/wallpapers`. It merges
only the listed configuration paths; it does not erase the rest of
`~/.config`.

Check the result:

~~~bash
./check-dependencies.sh
~~~

The normal restore only writes user-owned files. To reproduce the source
machine's SDDM wallpaper integration and persistent `btusb` autosuspend fix,
review and run the separate privileged installer:

~~~bash
sudo ./install-system.sh
~~~

It backs up each exact file it replaces under
`/var/lib/hyprland-setup/backups/`; it does not copy accounts, credentials, or
other SDDM configuration. Reboot after installing the Bluetooth module option.

### 3. Add wallpapers

Put images, GIFs, or videos in:

~~~text
~/Pictures/wallpapers
~~~

The files themselves are intentionally not versioned. Before the first
Hyprland login, either replace the placeholder in
`~/.config/waypaper/config.ini` or simply put at least one wallpaper in the
folder and run:

~~~bash
~/.config/hypr/scripts/cycle_wall.sh
~~~

### 4. Review hardware-specific configuration

Before starting Hyprland, check:

- the monitor declarations at the top of `~/.config/hypr/hyprland.lua`
- `~/.config/hypr/conf/monitors/auto.conf` when using the fallback config
- `~/.config/hypr/conf/keyboards/keyboard.conf`
- the `hl.device` block in `~/.config/hypr/hyprland.lua` (or the fallback
  `device` block in `hyprland.conf`)
- `~/.config/hypr/conf/environments/default.conf`
- `~/.config/hypr/conf/environments/nvidia.conf` if the new machine uses
  Nvidia

The checked-in Lua configuration reproduces the source laptop layout:
`HDMI-A-1` above `eDP-1`. Change those output names or positions before login
if `hyprctl monitors all` reports different hardware. The fallback Hyprlang
configuration retains automatic placement for portability.

### 5. Start the session and test it

Log out, select **Hyprland** in the display manager, and log in. Then test:

~~~bash
~/.config/hypr/scripts/cycle_wall.sh
~/.config/hypr/scripts/lock.sh
~~~

Useful checks:

~~~bash
hyprctl monitors all
pgrep -a waybar
pgrep -a swaync
tail -n 100 /tmp/hypridle.log
~~~

Wallpaper colors should update Waybar immediately. KDE/Qt and GTK applications
receive palette/theme reload signals where supported. Some applications may
need one restart after the first-ever installation.

## VPN module

The Waybar lock icon supports:

- Left click: open the VPN menu
- Right click: connect or disconnect Proton VPN
- Proton VPN sign-in in a Kitty window
- Tailscale connect/disconnect and guided home-server setup
- Importing WireGuard `.conf` or OpenVPN `.ovpn` files through
  NetworkManager
- Opening configured home-server applications

The home-server setup currently defaults to
`jeeblejuice@192.168.1.100`. Override it without editing the script:

~~~bash
HOME_VPN_SERVER=user@server ~/.config/waybar/scripts/setup_home_vpn.sh
~~~

Install Proton VPN and sign in on the new machine separately. Tailscale's
guided setup installs and authenticates interactively. Never commit exported
VPN profiles or files containing private keys.

## KMail, KWrite, and Dolphin

The repository restores appearance and layout only. KOrganizer's month-view
layout is included, but selected Google calendars and Akonadi resource IDs are
intentionally omitted. Ark/Gwenview/Okular recent-file and extraction histories
and Spectacle's last absolute save path are omitted as well.

For KMail:

1. Add accounts again using KMail's account wizard.
2. Store passwords in the new machine's KWallet.
3. Select the included Glassy message-viewer theme if KMail does not select it
   automatically.
4. Use KDE PIM Data Exporter separately if private mail data must be migrated.

The wallpaper script updates KMail reader links, unread colors, message HTML,
and KDE selection colors. Its optional live KMail refresh uses `gdb` and
`nm` against the running process; if a future KMail build changes internal
symbols, the normal on-disk palette update still works and a KMail restart
applies it.

KWrite's `Glass Dark` syntax theme is installed under
`~/.local/share/org.kde.syntax-highlighting/themes/`.

Plasma System Monitor's source pages are installed under
`~/.local/share/plasma-systemmonitor/`. The Overview page includes the source
laptop's disk sensor identifiers; select the new machine's disks in System
Monitor if those gauges are empty. The custom chart faces use a portable home
path and read the accent written by `wall_color.sh`.

## Optional integrations

- Obsidian: create and enable a snippet named
  `wallpaper-accent.css` inside any vault under `~/Documents`. The
  wallpaper script discovers matching snippets automatically.
- Plasma: the KDE autostart entry restores the same wallpaper. Plasma video
  wallpaper support additionally requires a compatible Plasma wallpaper
  plugin.
- Proton VPN and Tailscale are optional; the Waybar module shows an unavailable
  state when neither is installed.

## Main shortcuts

- `SUPER + W`: cycle wallpaper and regenerate colors
- `SUPER + Space`: switch keyboard layout and show its OSD
- `SUPER + O`: Obsidian
- `SUPER + Q`: close the focused window
- `SUPER + E`: Dolphin
- `SUPER + L`: lock
- `SUPER + Delete`: Wlogout
- `SUPER + Shift + C`: color picker
- `SUPER + Shift + B`: restart Waybar
- `SUPER + Shift + K`: KWrite
- `SUPER + Shift + M`: KMail
- `SUPER + Print`: region screenshot in Satty
- `SUPER + Shift + Print`: save a full screenshot
- `SUPER + Ctrl + Print`: copy a region screenshot

## Notes for a restoring Codex session

A coding agent restoring this setup should:

1. Read this README and run `./check-dependencies.sh`.
2. Install missing commands using the current Fedora package names or the
   linked upstream projects.
3. Run `./restore.sh`; do not manually scatter files one by one.
4. Review `install-system.sh` and run it only when the SDDM/Bluetooth system
   settings are appropriate for the target hardware.
5. Preserve VPN keys, KMail accounts, KWallet, browser profiles, and user data
   outside Git.
6. Use `hyprctl monitors all` and `hyprctl devices` to adapt only the
   monitor/input sections.
7. Confirm at least one wallpaper exists, then run
   `~/.config/hypr/scripts/cycle_wall.sh`.
8. Inspect `journalctl --user -b` and the `/tmp/glass-*.log` files if a
   component fails.
9. Keep `$HOME`-relative paths portable; do not replace them with a username
   from the old machine.
