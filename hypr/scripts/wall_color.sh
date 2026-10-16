#!/bin/bash
IMG="$1"
CACHE_SOURCE="${2:-$IMG}"

mkdir -p "$HOME/.cache"
exec 9>"$HOME/.cache/glass-wall-color.lock"
flock -x 9

sed -i 's/palette = ".*/palette = "dark"/' ~/.config/wallust/wallust.toml

sample_brightness() {
    magick "$1" \
        -auto-orient \
        -gravity north \
        -crop '100%x12%+0+0' \
        +repage \
        -colorspace Gray \
        -resize '12x1!' \
        txt:- 2>/dev/null \
        | awk '
            /^[0-9]+,0:/ && match($0, /\(([0-9.]+)\)/, channel) {
                value = channel[1] / 255
                if (!seen || value < darkest) darkest = value
                seen = 1
            }
            END { print seen ? darkest : 0.5 }
        '
}

CONTRAST_FILE="$HOME/.config/waybar/contrast.css"
WLOGOUT_COLORS_FILE="$HOME/.config/wlogout/colors.css"
WLOGOUT_ICON_DIR="$HOME/.cache/wlogout-icons"
KVANTUM_CONFIG="$HOME/.config/Kvantum/Glassy/Glassy.kvconfig"
KVANTUM_SVG="$HOME/.config/Kvantum/Glassy/Glassy.svg"
KVANTUM_ACCENT_STATE="$HOME/.config/Kvantum/Glassy/.wallpaper-accent"
KMAIL_GLASS_COLORS="$HOME/.local/share/messageviewer/themes/glassy/wallpaper.css"
GTK_THEME_DIR="$HOME/.themes/Glassy-Originals-Gtk-Purple-Dark"
GTK_THEME_NAME="Glassy-Originals-Gtk-Purple-Dark"
WAYBAR_COLORS="$HOME/.config/waybar/colors.css"
WAYBAR_STYLE="$HOME/.config/waybar/style.css"
WALLUST_WAYBAR_COLORS="$HOME/.cache/wallust-waybar-colors.css"
SYSTEM_MONITOR_OVERVIEW="$HOME/.local/share/plasma-systemmonitor/overview.page"
SYSTEM_MONITOR_ACCENT_FILE="$HOME/.cache/glass-system-monitor-accent"
PALETTE_CACHE_ROOT="$HOME/.cache/glass-wallpaper-palettes"
PALETTE_CACHE_VERSION="3"
CACHE_SOURCE_REAL="$(realpath "$CACHE_SOURCE" 2>/dev/null || printf '%s' "$CACHE_SOURCE")"
CACHE_SOURCE_STAT="$(stat -c '%s:%Y' "$CACHE_SOURCE" 2>/dev/null || printf 'unknown')"
PALETTE_CACHE_KEY="$(printf '%s\n%s\n%s\n' \
    "$PALETTE_CACHE_VERSION" "$CACHE_SOURCE_REAL" "$CACHE_SOURCE_STAT" \
    | sha256sum | cut -d' ' -f1)"
PALETTE_CACHE_DIR="$PALETTE_CACHE_ROOT/$PALETTE_CACHE_KEY"
CACHE_HIT=false
if [ -f "$PALETTE_CACHE_DIR/complete" ] \
    && [ -f "$PALETTE_CACHE_DIR/brightness" ] \
    && [ -f "$PALETTE_CACHE_DIR/dominant" ] \
    && [ -f "$PALETTE_CACHE_DIR/borders" ] \
    && [ -f "$PALETTE_CACHE_DIR/waybar.css" ] \
    && [ -f "$PALETTE_CACHE_DIR/rofi.rasi" ] \
    && [ -f "$PALETTE_CACHE_DIR/kitty.conf" ] \
    && [ -f "$PALETTE_CACHE_DIR/hyprland.conf" ] \
    && [ -f "$PALETTE_CACHE_DIR/wlogout.css" ] \
    && [ -f "$PALETTE_CACHE_DIR/swaync.css" ]; then
    CACHE_HIT=true
fi

# Cache one representative frame for video wallpapers so later palette
# changes do not invoke ffmpeg again.
if [ "$CACHE_HIT" = false ] \
    && [[ "${CACHE_SOURCE##*.}" =~ ^(mp4|MP4|webm|WEBM|mkv|MKV|gif|GIF)$ ]] \
    && command -v ffmpeg >/dev/null 2>&1; then
    mkdir -p "$PALETTE_CACHE_DIR"
    IMG="$PALETTE_CACHE_DIR/frame.jpg"
    ffmpeg -y -i "$CACHE_SOURCE" -ss 00:00:01.000 -vframes 1 "$IMG" -loglevel quiet
fi
OLD_WAYBAR_ACCENT="$(sed -n \
    's/^@define-color wallpaper_dominant \(#[[:xdigit:]]\{6\}\);$/\1/p' \
    "$WAYBAR_COLORS" | head -n 1)"
OBSIDIAN_ACCENT_FILES=()
if [ -d "$HOME/Documents" ]; then
    mapfile -d '' -t OBSIDIAN_ACCENT_FILES < <(
        find "$HOME/Documents" -path '*/.obsidian/snippets/wallpaper-accent.css' -print0
    )
fi

animate_waybar_accent() {
    local old="$1"
    local new="$2"
    local steps=6
    local step old_r old_g old_b new_r new_g new_b red green blue color

    if [[ ! "$old" =~ ^#[[:xdigit:]]{6}$ ]]; then
        old="$new"
    fi
    [[ "$new" =~ ^#[[:xdigit:]]{6}$ ]] || return

    old_r=$((16#${old:1:2}))
    old_g=$((16#${old:3:2}))
    old_b=$((16#${old:5:2}))
    new_r=$((16#${new:1:2}))
    new_g=$((16#${new:3:2}))
    new_b=$((16#${new:5:2}))

    for step in $(seq 1 "$steps"); do
        red=$((old_r + (new_r - old_r) * step / steps))
        green=$((old_g + (new_g - old_g) * step / steps))
        blue=$((old_b + (new_b - old_b) * step / steps))
        printf -v color '#%02X%02X%02X' "$red" "$green" "$blue"
        sed -i \
            "s/^@define-color wallpaper_dominant .*/@define-color wallpaper_dominant $color;/" \
            "$WAYBAR_COLORS"
        touch "$WAYBAR_STYLE"
        sleep 0.04
    done
}

update_kvantum_svg_accent() {
    local accent="$1"
    local old_accent="#B04783"
    local old_dark="#6D1758"
    local red green blue dark_accent
    local -a saved_accents

    if [ -f "$KVANTUM_ACCENT_STATE" ]; then
        readarray -t saved_accents < "$KVANTUM_ACCENT_STATE"
        old_accent="${saved_accents[0]:-$old_accent}"
        old_dark="${saved_accents[1]:-$old_dark}"
    fi

    red=$((16#${accent:1:2}))
    green=$((16#${accent:3:2}))
    blue=$((16#${accent:5:2}))
    printf -v dark_accent '#%02X%02X%02X' \
        "$((red * 55 / 100))" "$((green * 55 / 100))" "$((blue * 55 / 100))"

    if [[ "$old_accent" =~ ^#[[:xdigit:]]{6}$ ]] \
        && [[ "$old_dark" =~ ^#[[:xdigit:]]{6}$ ]] \
        && [ -f "$KVANTUM_SVG" ]; then
        # Glassy's original purple was spread across toolbar buttons, menus,
        # tabs, sliders, headers and item views. Replace the full accent pair
        # so every focused/pressed/toggled control follows the wallpaper.
        sed -i \
            -e "s/$old_accent/$accent/Ig" \
            -e "s/$old_dark/$dark_accent/Ig" \
            -e "s/#B04783/$accent/Ig" \
            -e "s/#6D1758/$dark_accent/Ig" \
            -e "s/#B74AFF/$accent/Ig" \
            -e "/id=\"lineedit-focused-left\"/,/id=\"lineedit-focused\"/ s/fill:#[[:xdigit:]]\{6\};fill-opacity:0\.47058824/fill:$accent;fill-opacity:0.47058824/Ig" \
            -e "/id=\"g786-3\"/,/inkscape:transform-center-y=\"5\"/ s/fill:#[[:xdigit:]]\{6\};fill-opacity:0\.47058824/fill:$accent;fill-opacity:0.47058824/Ig" \
            -e "/id=\"scrollbarslider-focused-topright\"/,/id=\"scrollbarslider-focused-bottomleft\"/ s/fill:#[[:xdigit:]]\{6\};fill-opacity:[0-9.]\+/fill:$accent;fill-opacity:0.78/Ig" \
            "$KVANTUM_SVG"
        printf '%s\n%s\n' "$accent" "$dark_accent" > "$KVANTUM_ACCENT_STATE"
    fi
}

reload_kvantum_style() {
    command -v kwriteconfig6 >/dev/null 2>&1 || return
    command -v dbus-send >/dev/null 2>&1 || return

    # Kvantum caches its SVG. Recreating the style makes running applications
    # reload it; Kvantum supports on-the-fly switches for this purpose.
    kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Fusion
    dbus-send --session --type=signal /KGlobalSettings \
        org.kde.KGlobalSettings.notifyChange int32:2 int32:0 \
        >/dev/null 2>&1 || true
    sleep 0.15
    kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum
    dbus-send --session --type=signal /KGlobalSettings \
        org.kde.KGlobalSettings.notifyChange int32:2 int32:0 \
        >/dev/null 2>&1 || true
}

update_qt_text_color() {
    local color="$1"
    local rgb="$2"
    local accent="$3"
    local accent_rgb="$4"
    local selection_text="$5"
    local selection_text_rgb="$6"
    local group

    # Dolphin gets its item-view foreground from KDE's View color set, while
    # Kvantum paints the transparent item view and inline rename editor. Keep
    # both palettes aligned with the same contrast choice used by Waybar.
    if command -v kwriteconfig6 >/dev/null 2>&1; then
        kwriteconfig6 --file kdeglobals --group 'Colors:View' \
            --key ForegroundNormal "$rgb"
        kwriteconfig6 --file kdeglobals --group 'Colors:Selection' \
            --key BackgroundNormal "$accent_rgb"
        kwriteconfig6 --file kdeglobals --group 'Colors:Selection' \
            --key BackgroundAlternate "$accent_rgb"
        kwriteconfig6 --file kdeglobals --group 'Colors:Selection' \
            --key ForegroundNormal "$selection_text_rgb"
        kwriteconfig6 --file kdeglobals --group General \
            --key AccentColor "$accent_rgb"
        kwriteconfig6 --file kdeglobals --group General \
            --key LastUsedCustomAccentColor "$accent_rgb"

        for group in 'Colors:View' 'Colors:Window' 'Colors:Button' \
            'Colors:Header' 'Colors:Header][Inactive' 'Colors:Selection'; do
            kwriteconfig6 --file kdeglobals --group "$group" \
                --key DecorationFocus "$accent_rgb"
            kwriteconfig6 --file kdeglobals --group "$group" \
                --key DecorationHover "$accent_rgb"
        done
    fi

    if [ -f "$KVANTUM_CONFIG" ]; then
        sed -i \
            -e "s/^highlight\.color=.*/highlight.color=$accent/" \
            -e "s/^inactive\.highlight\.color=.*/inactive.highlight.color=$accent/" \
            -e "s/^highlight\.text\.color=.*/highlight.text.color=$selection_text/" \
            -e "s/^text\.color=.*/text.color=$color/" \
            -e "s/^window\.text\.color=.*/window.text.color=$color/" \
            -e "s/^text\.normal\.color=.*/text.normal.color=$color/" \
            -e "s/^text\.focus\.color=.*/text.focus.color=$selection_text/" \
            -e "s/^text\.press\.color=.*/text.press.color=$selection_text/" \
            -e "s/^text\.toggle\.color=.*/text.toggle.color=$selection_text/" \
            "$KVANTUM_CONFIG"
    fi

    if [ -f "$KVANTUM_SVG" ]; then
        sed -i \
            "/id=\"scrollbarslider-normal-topleft\"/,/id=\"scrollbarslider-normal-bottomright\"/ s/fill:#[[:xdigit:]]\{6\};fill-opacity:[0-9.]\+/fill:#F4F6F8;fill-opacity:0.58/Ig" \
            "$KVANTUM_SVG"
    fi

    # Broadcast PaletteChanged. KDE applications listen for this signal and
    # rebuild their KColorScheme/QPalette without needing a new login.
    if command -v dbus-send >/dev/null 2>&1; then
        dbus-send --session --type=signal /KGlobalSettings \
            org.kde.KGlobalSettings.notifyChange int32:0 int32:0 \
            >/dev/null 2>&1 || true

    fi
}

update_system_monitor_overview() {
    local accent_rgb="$1"

    [ -f "$SYSTEM_MONITOR_OVERVIEW" ] || return
    sed -i \
        -e "s|^cpu/all/usage=.*|cpu/all/usage=$accent_rgb|" \
        -e "s|^gpu/all/usage=.*|gpu/all/usage=$accent_rgb|" \
        -e "s|^memory/physical/used=.*|memory/physical/used=$accent_rgb|" \
        -e "s|^memory/swap/used=.*|memory/swap/used=$accent_rgb|" \
        "$SYSTEM_MONITOR_OVERVIEW"
}

update_gtk_theme_accent() {
    local accent="$1"
    local red=$((16#${accent:1:2}))
    local green=$((16#${accent:3:2}))
    local blue=$((16#${accent:5:2}))
    local css
    local -a theme_files=(
        "$GTK_THEME_DIR/gtk-3.0/gtk.css"
        "$GTK_THEME_DIR/gtk-3.0/gtk-dark.css"
        "$GTK_THEME_DIR/gtk-3.0/libadwaita-tweaks.css"
        "$GTK_THEME_DIR/gtk-4.0/gtk.css"
        "$GTK_THEME_DIR/gtk-4.0/gtk-dark.css"
    )

    # The original theme used a fixed blue accent and literal purple glass
    # panels. Update both across GTK 3, GTK 4 and libadwaita.
    for css in "${theme_files[@]}"; do
        [ -f "$css" ] || continue
        sed -i \
            -e "s/^@define-color accent_bg_color .*/@define-color accent_bg_color $accent;/" \
            -e "s/^[[:space:]]*--accent-bg-color:[[:space:]]*[^;]*;/  --accent-bg-color: $accent;/" \
            -e "s/background-color:[[:space:]]*rgba([[:space:]]*[0-9]\+,[[:space:]]*[0-9]\+,[[:space:]]*[0-9]\+,[[:space:]]*0\.5)/background-color: rgba($red,$green,$blue,0.5)/" \
            "$css"
    done

    # Changing a theme file does not invalidate GTK's already-loaded CSS
    # provider. Toggle the GtkSettings theme property so running applications
    # discard that provider and load the newly recolored files immediately.
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface gtk-theme Adwaita
        sleep 0.1
        gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME_NAME"
    fi
}

update_obsidian_highlights() {
    local accent="$1"
    local red=$((16#${accent:1:2}))
    local green=$((16#${accent:3:2}))
    local blue=$((16#${accent:5:2}))
    local css

    # Obsidian watches enabled snippet files and reparses them in-place, so
    # selections and highlights update without reloading a vault.
    for css in "${OBSIDIAN_ACCENT_FILES[@]}"; do
        [ -f "$css" ] || continue
        sed -i \
            -e "s/^    --wallpaper-accent: .*/    --wallpaper-accent: $accent;/" \
            -e "s/^    --wallpaper-accent-rgb: .*/    --wallpaper-accent-rgb: $red, $green, $blue;/" \
            -e "s/^    --wallpaper-selection: .*/    --wallpaper-selection: rgba($red, $green, $blue, 0.42);/" \
            -e "s/^    --wallpaper-highlight: .*/    --wallpaper-highlight: rgba($red, $green, $blue, 0.30);/" \
            -e "s/^    --wallpaper-soft: .*/    --wallpaper-soft: rgba($red, $green, $blue, 0.18);/" \
            "$css"
    done
}

update_kmail_glass_theme() {
    local accent="$1"
    local readable_accent="$2"
    local foreground="$3"
    local selection_foreground="$4"
    local link_rgb="$5"

    mkdir -p "$(dirname "$KMAIL_GLASS_COLORS")"
    printf '%s\n' \
        ':root {' \
        "    --glass-accent: $accent;" \
        "    --glass-accent-readable: $readable_accent;" \
        "    --glass-accent-soft: ${accent}38;" \
        "    --glass-accent-faint: ${accent}1F;" \
        '    --glass-foreground: #F8FAFC;' \
        "    --glass-selection-foreground: $selection_foreground;" \
        '    --glass-scrollbar: #F8FAFCB0;' \
        '}' > "$KMAIL_GLASS_COLORS"

    # KMail's native link palette is separate from the HTML header theme.
    # Update it as well so plain messages and generated viewer elements agree.
    if command -v kwriteconfig6 >/dev/null 2>&1; then
        kwriteconfig6 --file kmail2rc --group Reader --key LinkColor "$link_rgb"
        kwriteconfig6 --file kmail2rc --group 'MessageListView::Colors' \
            --key UnreadMessageColor "$link_rgb"
        kwriteconfig6 --file kdeglobals --group 'Colors:View' \
            --key ForegroundActive "$link_rgb"
        kwriteconfig6 --file kdeglobals --group 'Colors:View' \
            --key ForegroundLink "$link_rgb"
        kwriteconfig6 --file kdeglobals --group 'Colors:Selection' \
            --key ForegroundActive "$link_rgb"
        kwriteconfig6 --file kdeglobals --group 'Colors:Selection' \
            --key ForegroundLink "$link_rgb"
    fi

    if [ -f "$KVANTUM_CONFIG" ]; then
        sed -i "s/^link\.color=.*/link.color=$readable_accent/" \
            "$KVANTUM_CONFIG"
    fi

    # MessageListSettings caches unread colors. Unlike the KDE selection
    # palette, editing kmail2rc alone does not refresh a running KMail.
    if command -v dbus-send >/dev/null 2>&1; then
        dbus-send --session --type=method_call --dest=org.kde.kmail2 \
            /KMail org.kde.kmail.kmail.updateConfig \
            >/dev/null 2>&1 || true
    fi
}

refresh_kmail_unread_color_live() {
    local red="$1"
    local green="$2"
    local blue="$3"
    local kmail_pid current_collection gdb_status=0
    local qt_base qt_path message_base message_path libc_base libc_path
    local rgb_offset unread_offset
    local calloc_offset free_offset
    local rgb_address unread_address
    local calloc_address free_address

    command -v gdb >/dev/null 2>&1 || return
    command -v nm >/dev/null 2>&1 || return
    command -v pgrep >/dev/null 2>&1 || return

    kmail_pid="$(pgrep -n -x kmail 2>/dev/null || true)"
    [ -n "$kmail_pid" ] || return

    # Resolve the four exported functions directly from KMail's loaded
    # mappings. This avoids GDB scanning every Qt/WebEngine symbol table,
    # which made each wallpaper change take several seconds.
    read -r qt_base qt_path < <(
        awk '$3 == "00000000" && /libQt6Gui\.so/ {
            split($1, range, "-"); print range[1], $6; exit
        }' "/proc/$kmail_pid/maps"
    )
    read -r message_base message_path < <(
        awk '$3 == "00000000" && /libKPim6MessageList\.so/ {
            split($1, range, "-"); print range[1], $6; exit
        }' "/proc/$kmail_pid/maps"
    )
    read -r libc_base libc_path < <(
        awk '$3 == "00000000" && /\/libc\.so/ {
            split($1, range, "-"); print range[1], $6; exit
        }' "/proc/$kmail_pid/maps"
    )
    [ -n "$qt_path" ] && [ -n "$message_path" ] && [ -n "$libc_path" ] \
        || return 1

    rgb_offset="$(
        nm -D "$qt_path" 2>/dev/null |
            awk '$3 ~ /^_ZN6QColor6setRgbEiiii(@@.*)?$/ { print $1; exit }'
    )"
    unread_offset="$(
        nm -D "$message_path" 2>/dev/null |
            awk '$3 ~ /^_ZN11MessageList4Core11MessageItem21setUnreadMessageColorERK6QColor$/ { print $1; exit }'
    )"
    calloc_offset="$(
        nm -D "$libc_path" 2>/dev/null |
            awk '$3 ~ /^calloc@@/ { print $1; exit }'
    )"
    free_offset="$(
        nm -D "$libc_path" 2>/dev/null |
            awk '$3 ~ /^free@@/ { print $1; exit }'
    )"
    [[ "$qt_base$message_base$libc_base$rgb_offset$unread_offset$calloc_offset$free_offset" \
        =~ ^[[:xdigit:]]+$ ]] || return 1

    printf -v rgb_address '0x%x' \
        "$((16#$qt_base + 16#$rgb_offset))"
    printf -v unread_address '0x%x' \
        "$((16#$message_base + 16#$unread_offset))"
    printf -v calloc_address '0x%x' \
        "$((16#$libc_base + 16#$calloc_offset))"
    printf -v free_address '0x%x' \
        "$((16#$libc_base + 16#$free_offset))"

    # KMail copies the configured unread color into a process-global brush.
    # Its updateConfig D-Bus method does not replace that brush. Call the
    # library's exported setter in the running process; the short attach is
    # non-interactive and skipped entirely when KMail is closed.
    timeout --signal=INT --kill-after=2s 5s gdb -q -n -batch \
        -iex 'set debuginfod enabled off' \
        -iex 'set print thread-events off' \
        -iex 'set auto-solib-add off' \
        -iex 'set unwind-on-signal on' \
        -p "$kmail_pid" \
        -ex "set \$calloc=(void*)$calloc_address" \
        -ex "set \$free=(void*)$free_address" \
        -ex "set \$setrgb=(void*)$rgb_address" \
        -ex "set \$setunread=(void*)$unread_address" \
        -ex 'set $color=((void*(*)(long,long))$calloc)(1,32)' \
        -ex "call ((void(*)(void*,int,int,int,int))\$setrgb)(\$color,$red,$green,$blue,255)" \
        -ex 'call ((void(*)(void*))$setunread)($color)' \
        -ex 'call ((void(*)(void*))$free)($color)' \
        -ex 'detach' \
        >/dev/null 2>&1 || gdb_status=$?

    # A killed debugger normally detaches automatically, but explicitly send
    # SIGCONT as a final guard so a timeout can never leave KMail paused.
    kill -CONT "$kmail_pid" 2>/dev/null || true
    [ "$gdb_status" -eq 0 ] || return

    # Rebuild the visible message rows so they pick up the new unread brush.
    # CollectionFolderView/Current is kept in sync by KMail when the user
    # selects a folder; unlike the removed model/count experiments, this is
    # the original refresh path that was verified to update unread rows.
    if command -v kreadconfig6 >/dev/null 2>&1 \
        && command -v dbus-send >/dev/null 2>&1; then
        current_collection="$(
            kreadconfig6 --file kmail2rc --group CollectionFolderView \
                --key Current 2>/dev/null || true
        )"
        current_collection="${current_collection#c}"
        if [[ "$current_collection" =~ ^[0-9]+$ ]]; then
            dbus-send --session --type=method_call --dest=org.kde.kmail2 \
                /KMail org.kde.kmail.kmail.showFolder \
                string:"$current_collection" \
                >/dev/null 2>&1 || true
        fi
    fi

}

refresh_kmail_folder_counts_live() {
    local kmail_pid qt_base qt_path mail_base mail_path libc_base libc_path
    local heap_start heap_end timer_offset vtable_offset calloc_offset free_offset
    local timer_address widget_vptr calloc_address free_address gdb_status=0

    command -v gdb >/dev/null 2>&1 || return
    command -v nm >/dev/null 2>&1 || return
    kmail_pid="$(pgrep -n -x kmail 2>/dev/null || true)"
    [ -n "$kmail_pid" ] || return

    read -r qt_base qt_path < <(
        awk '$3 == "00000000" && /libQt6Core\.so/ {
            split($1, range, "-"); print range[1], $6; exit
        }' "/proc/$kmail_pid/maps"
    )
    read -r mail_base mail_path < <(
        awk '$3 == "00000000" && /libKPim6MailCommon\.so/ {
            split($1, range, "-"); print range[1], $6; exit
        }' "/proc/$kmail_pid/maps"
    )
    read -r libc_base libc_path < <(
        awk '$3 == "00000000" && /\/libc\.so/ {
            split($1, range, "-"); print range[1], $6; exit
        }' "/proc/$kmail_pid/maps"
    )
    read -r heap_start heap_end < <(
        awk '/\[heap\]/ {
            split($1, range, "-"); print range[1], range[2]; exit
        }' "/proc/$kmail_pid/maps"
    )

    timer_offset="$(
        nm -D "$qt_path" 2>/dev/null |
            awk '$3 ~ /^_ZN6QTimer10singleShotEiPK7QObjectPKc(@@.*)?$/ { print $1; exit }'
    )"
    vtable_offset="$(
        nm -D "$mail_path" 2>/dev/null |
            awk '$3 == "_ZTVN10MailCommon16FolderTreeWidgetE" { print $1; exit }'
    )"
    calloc_offset="$(
        nm -D "$libc_path" 2>/dev/null |
            awk '$3 ~ /^calloc@@/ { print $1; exit }'
    )"
    free_offset="$(
        nm -D "$libc_path" 2>/dev/null |
            awk '$3 ~ /^free@@/ { print $1; exit }'
    )"
    [[ "$qt_base$mail_base$libc_base$heap_start$heap_end$timer_offset$vtable_offset$calloc_offset$free_offset" \
        =~ ^[[:xdigit:]]+$ ]] || return 1

    printf -v timer_address '0x%x' "$((16#$qt_base + 16#$timer_offset))"
    printf -v widget_vptr '0x%x' "$((16#$mail_base + 16#$vtable_offset + 16))"
    printf -v calloc_address '0x%x' "$((16#$libc_base + 16#$calloc_offset))"
    printf -v free_address '0x%x' "$((16#$libc_base + 16#$free_offset))"

    # Queue only FolderTreeWidget::slotGeneralPaletteChanged() on KMail's GUI
    # thread. The slot refreshes the folder proxy/view palette and does not
    # touch the message list, current folder, or selected message.
    timeout --signal=INT --kill-after=2s 5s gdb -q -n -batch \
        -iex 'set debuginfod enabled off' \
        -iex 'set print thread-events off' \
        -iex 'set auto-solib-add off' \
        -iex 'set unwind-on-signal on' \
        -p "$kmail_pid" \
        -ex "find /g 0x$heap_start, 0x$heap_end, $widget_vptr" \
        -ex 'if $numfound > 0' \
        -ex 'set $widget=(void*)$_' \
        -ex "set \$calloc=(void*)$calloc_address" \
        -ex "set \$free=(void*)$free_address" \
        -ex 'set $method=((void*(*)(long,long))$calloc)(1,29)' \
        -ex 'set {char[29]}$method = "1slotGeneralPaletteChanged()"' \
        -ex "call ((void(*)(int,void*,char*))$timer_address)(0,\$widget,\$method)" \
        -ex 'call ((void(*)(void*))$free)($method)' \
        -ex 'end' \
        -ex 'detach' \
        >/dev/null 2>&1 || gdb_status=$?
    kill -CONT "$kmail_pid" 2>/dev/null || true
    return "$gdb_status"
}

update_wlogout_icons() {
    local color="$1"
    local name source

    mkdir -p "$WLOGOUT_ICON_DIR"
    for name in lock logout suspend hibernate shutdown reboot; do
        source="/usr/share/wlogout/icons/$name.png"
        [ -f "$source" ] || continue
        magick "$source" \
            -channel RGB \
            -fill "$color" \
            -colorize 100 \
            +channel \
            "$WLOGOUT_ICON_DIR/$name.png"
    done
}

color_is_chromatic() {
    local color="$1"
    local red green blue min max

    [[ "$color" =~ ^#[[:xdigit:]]{6}$ ]] || return 1
    red=$((16#${color:1:2}))
    green=$((16#${color:3:2}))
    blue=$((16#${color:5:2}))
    min="$red"
    max="$red"
    ((green < min)) && min="$green"
    ((blue < min)) && min="$blue"
    ((green > max)) && max="$green"
    ((blue > max)) && max="$blue"
    ((max > 0 && 100 * (max - min) >= 30 * max))
}

normalize_accent_color() {
    local color="$1"
    local red=$((16#${color:1:2}))
    local green=$((16#${color:3:2}))
    local blue=$((16#${color:5:2}))

    awk -v r="$red" -v g="$green" -v b="$blue" '
        function render_hsv( sector, fraction, p, q, t) {
            sector = int(h * 6)
            fraction = h * 6 - sector
            p = v * (1 - s)
            q = v * (1 - fraction * s)
            t = v * (1 - (1 - fraction) * s)
            sector %= 6
            if (sector == 0)      { rr = v; gg = t; bb = p }
            else if (sector == 1) { rr = q; gg = v; bb = p }
            else if (sector == 2) { rr = p; gg = v; bb = t }
            else if (sector == 3) { rr = p; gg = q; bb = v }
            else if (sector == 4) { rr = t; gg = p; bb = v }
            else                  { rr = v; gg = p; bb = q }
            luma = 255 * (0.299 * rr + 0.587 * gg + 0.114 * bb)
        }
        BEGIN {
            r /= 255; g /= 255; b /= 255
            max = r; if (g > max) max = g; if (b > max) max = b
            min = r; if (g < min) min = g; if (b < min) min = b
            delta = max - min
            if (delta == 0) h = 0
            else if (max == r) h = ((g - b) / delta) / 6
            else if (max == g) h = ((b - r) / delta + 2) / 6
            else h = ((r - g) / delta + 4) / 6
            if (h < 0) h++
            s = max == 0 ? 0 : delta / max
            v = max
            if (s < 0.45) s = 0.45
            if (v < 0.72) v = 0.72
            render_hsv()
            while (luma < 130 && v < 0.999) { v += 0.02; if (v > 1) v = 1; render_hsv() }
            while (luma < 130 && s > 0.45) { s -= 0.02; if (s < 0.45) s = 0.45; render_hsv() }
            printf "#%02X%02X%02X\n", int(rr * 255 + 0.5), int(gg * 255 + 0.5), int(bb * 255 + 0.5)
        }
    '
}

pick_chromatic_color() {
    awk '
        match($0, /^[[:space:]]*([0-9]+):/, amount) &&
        match($0, /\(([0-9.]+),([0-9.]+),([0-9.]+)\)/, channel) &&
        match($0, /#[[:xdigit:]]{6}/) {
            hex = substr($0, RSTART, RLENGTH)

            min = max = channel[1]
            for (i = 2; i <= 3; i++) {
                if (channel[i] < min) min = channel[i]
                if (channel[i] > max) max = channel[i]
            }

            saturation = max == 0 ? 0 : (max - min) / max
            brightness = max / 255
            score = amount[1] * saturation * brightness * brightness

            if (max >= 55 && saturation >= 0.22 && score > strong_score) {
                strong_score = score
                strong_color = hex
            } else if (max >= 55 && saturation >= 0.06 && score > muted_score) {
                muted_score = score
                muted_color = hex
            }
        }

        END { print strong_color != "" ? strong_color : muted_color }
    '
}

dominant_color() {
    local color

    color="$(
        magick "$1" \
            -auto-orient \
            -gravity center \
            -crop '50%x50%+0+0' \
            +repage \
            -thumbnail '128x128^' \
            -gravity center \
            -extent 128x128 \
            +dither \
            -colors 24 \
            -format '%c' histogram:info:- 2>/dev/null \
            | pick_chromatic_color
    )"

    # If the middle is neutral, look across the whole wallpaper for a real hue.
    if [ -z "$color" ]; then
        color="$(
            magick "$1" \
                -auto-orient \
                -thumbnail '128x128^' \
                -gravity center \
                -extent 128x128 \
                +dither \
                -colors 24 \
                -format '%c' histogram:info:- 2>/dev/null \
                | pick_chromatic_color
        )"
    fi

    printf '%s\n' "$color"
}

sample_wallpaper_colors() {
    magick "$1" \
        -auto-orient \
        -thumbnail '128x128^' \
        -gravity center \
        -extent 128x128 \
        +dither \
        -colors 24 \
        -format '%c' histogram:info:- 2>/dev/null \
        | awk '
            match($0, /^[[:space:]]*([0-9]+):/, amount) &&
            match($0, /\(([0-9.]+),([0-9.]+),([0-9.]+)\)/, channel) &&
            match($0, /#[[:xdigit:]]{6}/) {
                n++
                count[n] = amount[1]
                red[n] = channel[1]
                green[n] = channel[2]
                blue[n] = channel[3]
                hex[n] = substr($0, RSTART, RLENGTH)

                min = max = red[n]
                if (green[n] < min) min = green[n]
                if (blue[n] < min) min = blue[n]
                if (green[n] > max) max = green[n]
                if (blue[n] > max) max = blue[n]

                saturation = max == 0 ? 0 : (max - min) / max
                brightness = max / 255
                score[n] = count[n] * (0.30 + saturation) * (0.25 + brightness)
            }

            END {
                for (pick = 1; pick <= 3; pick++) {
                    best = 0
                    best_score = -1

                    for (i = 1; i <= n; i++) {
                        if (used[i]) continue

                        distinct = 1
                        for (j = 1; j < pick; j++) {
                            dr = red[i] - chosen_red[j]
                            dg = green[i] - chosen_green[j]
                            db = blue[i] - chosen_blue[j]
                            if (dr * dr + dg * dg + db * db < 1600) distinct = 0
                        }

                        if (distinct && score[i] > best_score) {
                            best = i
                            best_score = score[i]
                        }
                    }

                    if (!best) {
                        for (i = 1; i <= n; i++) {
                            if (!used[i] && score[i] > best_score) {
                                best = i
                                best_score = score[i]
                            }
                        }
                    }

                    if (best) {
                        print hex[best]
                        used[best] = 1
                        chosen_red[pick] = red[best]
                        chosen_green[pick] = green[best]
                        chosen_blue[pick] = blue[best]
                    }
                }
            }
        '
}

if [ "$CACHE_HIT" = true ]; then
    BRIGHTNESS="$(<"$PALETTE_CACHE_DIR/brightness")"
    DOMINANT_COLOR="$(<"$PALETTE_CACHE_DIR/dominant")"
    mapfile -t BORDER_COLORS < "$PALETTE_CACHE_DIR/borders"
else
    BRIGHTNESS="$(sample_brightness "$IMG" || echo 0.5)"
    DOMINANT_COLOR="$(dominant_color "$IMG" || true)"
    mapfile -t BORDER_COLORS < <(sample_wallpaper_colors "$IMG")

    if [[ "$DOMINANT_COLOR" =~ ^#[[:xdigit:]]{6}$ ]]; then
        DOMINANT_COLOR="$(normalize_accent_color "$DOMINANT_COLOR")"
    elif color_is_chromatic "$OLD_WAYBAR_ACCENT"; then
        DOMINANT_COLOR="$(normalize_accent_color "$OLD_WAYBAR_ACCENT")"
    else
        DOMINANT_COLOR="#7AA2F7"
    fi

    for index in "${!BORDER_COLORS[@]}"; do
        if color_is_chromatic "${BORDER_COLORS[index]}"; then
            BORDER_COLORS[index]="$(normalize_accent_color "${BORDER_COLORS[index]}")"
        else
            BORDER_COLORS[index]="$DOMINANT_COLOR"
        fi
    done
fi

if awk -v b="$BRIGHTNESS" 'BEGIN { exit !(b > 0.64) }'; then
    ICON_COLOR="#111111"
    cat > "$CONTRAST_FILE" <<'EOF'
@define-color module_fg #111111;
@define-color module_border rgba(0, 0, 0, 0.22);
EOF
else
    ICON_COLOR="#F4F6F8"
    cat > "$CONTRAST_FILE" <<'EOF'
@define-color module_fg #F4F6F8;
@define-color module_border rgba(255, 255, 255, 0.18);
EOF
fi

# Restore a cached palette or ask Wallust to calculate it once. Wallust's OSC
# sequences are suppressed because wallpaper changes do not run in a terminal.
if [ "$CACHE_HIT" = true ]; then
    cp "$PALETTE_CACHE_DIR/waybar.css" "$WALLUST_WAYBAR_COLORS"
    cp "$PALETTE_CACHE_DIR/rofi.rasi" "$HOME/.config/rofi/colors.rasi"
    cp "$PALETTE_CACHE_DIR/kitty.conf" "$HOME/.config/kitty/colors.conf"
    cp "$PALETTE_CACHE_DIR/hyprland.conf" "$HOME/.config/hypr/colors-wallust.conf"
    cp "$PALETTE_CACHE_DIR/wlogout.css" "$HOME/.config/wlogout/colors.css"
    cp "$PALETTE_CACHE_DIR/swaync.css" "$HOME/.config/swaync/colors.css"
else
    wallust run --skip-sequences --quiet "$IMG" >/dev/null 2>&1
    mkdir -p "$PALETTE_CACHE_DIR"
    printf '%s\n' "$BRIGHTNESS" > "$PALETTE_CACHE_DIR/brightness"
    printf '%s\n' "$DOMINANT_COLOR" > "$PALETTE_CACHE_DIR/dominant"
    printf '%s\n' "${BORDER_COLORS[@]}" > "$PALETTE_CACHE_DIR/borders"
    cp "$WALLUST_WAYBAR_COLORS" "$PALETTE_CACHE_DIR/waybar.css"
    cp "$HOME/.config/rofi/colors.rasi" "$PALETTE_CACHE_DIR/rofi.rasi"
    cp "$HOME/.config/kitty/colors.conf" "$PALETTE_CACHE_DIR/kitty.conf"
    cp "$HOME/.config/hypr/colors-wallust.conf" "$PALETTE_CACHE_DIR/hyprland.conf"
    cp "$HOME/.config/wlogout/colors.css" "$PALETTE_CACHE_DIR/wlogout.css"
    cp "$HOME/.config/swaync/colors.css" "$PALETTE_CACHE_DIR/swaync.css"
    : > "$PALETTE_CACHE_DIR/complete"
fi

# Stage Wallust's complete Waybar palette without first exposing its generated
# accent. Keep the current accent until the smooth transition below.
if [ -f "$WALLUST_WAYBAR_COLORS" ]; then
    if [[ "$OLD_WAYBAR_ACCENT" =~ ^#[[:xdigit:]]{6}$ ]]; then
        sed -i \
            "s/^@define-color wallpaper_dominant .*/@define-color wallpaper_dominant $OLD_WAYBAR_ACCENT;/" \
            "$WALLUST_WAYBAR_COLORS"
    fi
    cp "$WALLUST_WAYBAR_COLORS" "${WAYBAR_COLORS}.tmp.$$"
    mv -f "${WAYBAR_COLORS}.tmp.$$" "$WAYBAR_COLORS"
fi

# Match wlogout labels to the wallpaper-aware monochrome icons.
sed -i "s/^@define-color action_foreground .*/@define-color action_foreground $ICON_COLOR;/" \
    "$WLOGOUT_COLORS_FILE"

if [ "${#BORDER_COLORS[@]}" -gt 0 ]; then
    BORDER_COLOR_1="${BORDER_COLORS[0]}"
    BORDER_COLOR_2="${BORDER_COLORS[1]:-${BORDER_COLORS[0]}}"
    BORDER_COLOR_3="${BORDER_COLORS[2]:-${BORDER_COLORS[0]}}"

    sed -i \
        -e "s/^\\\$wallpaper_border1 = .*/\\\$wallpaper_border1 = rgb(${BORDER_COLOR_1#\#})/" \
        -e "s/^\\\$wallpaper_border2 = .*/\\\$wallpaper_border2 = rgb(${BORDER_COLOR_2#\#})/" \
        -e "s/^\\\$wallpaper_border3 = .*/\\\$wallpaper_border3 = rgb(${BORDER_COLOR_3#\#})/" \
        "$HOME/.config/hypr/colors-wallust.conf"
fi

if [[ "$DOMINANT_COLOR" =~ ^#[[:xdigit:]]{6}$ ]]; then
    ACCENT_RED=$((16#${DOMINANT_COLOR:1:2}))
    ACCENT_GREEN=$((16#${DOMINANT_COLOR:3:2}))
    ACCENT_BLUE=$((16#${DOMINANT_COLOR:5:2}))
    ACCENT_RGB="$ACCENT_RED,$ACCENT_GREEN,$ACCENT_BLUE"

    printf '%s\n' "$DOMINANT_COLOR" > "${SYSTEM_MONITOR_ACCENT_FILE}.tmp.$$"
    mv -f "${SYSTEM_MONITOR_ACCENT_FILE}.tmp.$$" "$SYSTEM_MONITOR_ACCENT_FILE"

    if awk -v r="$ACCENT_RED" -v g="$ACCENT_GREEN" -v b="$ACCENT_BLUE" \
        'BEGIN { exit !((0.299*r + 0.587*g + 0.114*b) > 150) }'; then
        SELECTION_TEXT_COLOR="#111111"
        SELECTION_TEXT_RGB="17,17,17"
    else
        SELECTION_TEXT_COLOR="#F4F6F8"
        SELECTION_TEXT_RGB="244,246,248"
    fi

    # Links sit on KMail's dark translucent message surface. Lighten only the
    # link rendering when the wallpaper accent itself would be hard to read;
    # selections, outlines, and native highlights keep the exact sampled hue.
    LINK_RED="$ACCENT_RED"
    LINK_GREEN="$ACCENT_GREEN"
    LINK_BLUE="$ACCENT_BLUE"
    if awk -v r="$ACCENT_RED" -v g="$ACCENT_GREEN" -v b="$ACCENT_BLUE" \
        'BEGIN { exit !((0.299*r + 0.587*g + 0.114*b) < 145) }'; then
        LINK_RED=$(((ACCENT_RED * 55 + 255 * 45) / 100))
        LINK_GREEN=$(((ACCENT_GREEN * 55 + 255 * 45) / 100))
        LINK_BLUE=$(((ACCENT_BLUE * 55 + 255 * 45) / 100))
    fi
    printf -v LINK_COLOR '#%02X%02X%02X' \
        "$LINK_RED" "$LINK_GREEN" "$LINK_BLUE"
    LINK_RGB="$LINK_RED,$LINK_GREEN,$LINK_BLUE"

    # Update visible desktop surfaces before slower application integrations.
    sed -i "s/^@define-color wallpaper_dominant .*/@define-color wallpaper_dominant $DOMINANT_COLOR;/" \
        "$HOME/.config/wlogout/colors.css"
    sed -i "s/^@define-color wallpaper_dominant .*/@define-color wallpaper_dominant $DOMINANT_COLOR;/" \
        "$HOME/.config/swaync/colors.css"
    sed -i "s/^\\\$wallpaper_dominant = .*/\\\$wallpaper_dominant = rgb(${DOMINANT_COLOR#\#})/" \
        "$HOME/.config/hypr/colors-wallust.conf"

    # Keep Rofi's outline and selection in sync with Waybar's muted accent.
    sed -i \
        -e "s/^[[:space:]]*accent-col: .*/    accent-col: $DOMINANT_COLOR;/" \
        -e "s/^[[:space:]]*accent-soft: .*/    accent-soft: ${DOMINANT_COLOR}66;/" \
        -e "s/^[[:space:]]*sel-bg: .*/    sel-bg: ${DOMINANT_COLOR}D1;/" \
        "$HOME/.config/rofi/colors.rasi"

    if pgrep -x waybar >/dev/null 2>&1; then
        animate_waybar_accent "$OLD_WAYBAR_ACCENT" "$DOMINANT_COLOR"
    else
        sed -i \
            "s/^@define-color wallpaper_dominant .*/@define-color wallpaper_dominant $DOMINANT_COLOR;/" \
            "$WAYBAR_COLORS"
    fi
    if [[ "${XDG_CURRENT_DESKTOP:-}" != *KDE* ]] && [ -z "${KDE_FULL_SESSION:-}" ] \
        && command -v swaync-client >/dev/null 2>&1; then
        timeout 1s swaync-client -rs >/dev/null 2>&1 || true
    fi
    timeout 1s hyprctl reload >/dev/null 2>&1 || true

    update_wlogout_icons "$ICON_COLOR"
    update_qt_text_color "#F4F6F8" "244,246,248" \
        "$DOMINANT_COLOR" "$ACCENT_RGB" \
        "$SELECTION_TEXT_COLOR" "$SELECTION_TEXT_RGB"
    update_system_monitor_overview "$ACCENT_RGB"
    update_kvantum_svg_accent "$DOMINANT_COLOR"
    update_gtk_theme_accent "$DOMINANT_COLOR"
    update_obsidian_highlights "$DOMINANT_COLOR"
    update_kmail_glass_theme "$DOMINANT_COLOR" "$LINK_COLOR" \
        "$ICON_COLOR" "$SELECTION_TEXT_COLOR" "$LINK_RGB"
    refresh_kmail_unread_color_live \
        "$LINK_RED" "$LINK_GREEN" "$LINK_BLUE"
fi

reload_kvantum_style || true
refresh_kmail_folder_counts_live || true
