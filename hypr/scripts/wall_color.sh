#!/bin/bash
IMG="$1"

mkdir -p "$HOME/.cache"
exec 9>"$HOME/.cache/glass-wall-color.lock"
flock -x 9

sed -i 's/palette = ".*/palette = "dark"/' ~/.config/wallust/wallust.toml

sample_brightness() {
    magick "$1" \
        -gravity north \
        -crop 50%x8%+50%+0 \
        +repage \
        -colorspace Gray \
        -format '%[fx:mean]' info: 2>/dev/null
}

BRIGHTNESS="$(sample_brightness "$IMG" || echo 0.5)"
CONTRAST_FILE="$HOME/.config/waybar/contrast.css"
WLOGOUT_COLORS_FILE="$HOME/.config/wlogout/colors.css"
WLOGOUT_ICON_DIR="$HOME/.cache/wlogout-icons"
KVANTUM_CONFIG="$HOME/.config/Kvantum/Glassy/Glassy.kvconfig"
KVANTUM_SVG="$HOME/.config/Kvantum/Glassy/Glassy.svg"
KVANTUM_ACCENT_STATE="$HOME/.config/Kvantum/Glassy/.wallpaper-accent"
KMAIL_GLASS_COLORS="$HOME/.local/share/messageviewer/themes/glassy/wallpaper.css"
GTK_THEME_DIR="$HOME/.themes/Glassy-Originals-Gtk-Purple-Dark"
GTK_THEME_NAME="Glassy-Originals-Gtk-Purple-Dark"
PYWAL_COLORS="$HOME/.cache/wal/colors.json"
PYWALFOX_BIN="$HOME/.local/bin/pywalfox"
OBSIDIAN_ACCENT_FILES=()
if [ -d "$HOME/Documents" ]; then
    mapfile -d '' -t OBSIDIAN_ACCENT_FILES < <(
        find "$HOME/Documents" -path '*/.obsidian/snippets/wallpaper-accent.css' -print0
    )
fi

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

update_pywalfox_palette() {
    local accent="$1"
    local background foreground
    local -a colors
    local index

    [ -x "$PYWALFOX_BIN" ] || return
    mkdir -p "$(dirname "$PYWAL_COLORS")"

    background="$(sed -n 's/^@define-color background \(#[[:xdigit:]]\{6\}\);/\1/p' \
        "$HOME/.config/waybar/colors.css" | head -n 1)"
    foreground="$(sed -n 's/^@define-color foreground \(#[[:xdigit:]]\{6\}\);/\1/p' \
        "$HOME/.config/waybar/colors.css" | head -n 1)"
    background="${background:-#141618}"
    foreground="${foreground:-#F4F6F8}"

    for index in {0..8}; do
        colors[index]="$(sed -n "s/^@define-color color$index \\(#[[:xdigit:]]\\{6\\}\\);/\\1/p" \
            "$HOME/.config/waybar/colors.css" | head -n 1)"
    done
    colors[0]="${colors[0]:-$background}"
    colors[1]="$accent"
    for index in {2..8}; do
        colors[index]="${colors[index]:-$accent}"
    done

    printf '{\n  "wallpaper": "%s",\n  "alpha": "100",\n' "$IMG" > "$PYWAL_COLORS"
    printf '  "special": {"background": "%s", "foreground": "%s", "cursor": "%s"},\n' \
        "$background" "$foreground" "$foreground" >> "$PYWAL_COLORS"
    printf '  "colors": {\n' >> "$PYWAL_COLORS"
    for index in {0..15}; do
        if [ "$index" -le 8 ]; then
            color="${colors[index]}"
        else
            color="${colors[index-8]}"
        fi
        if [ "$index" -lt 15 ]; then
            printf '    "color%d": "%s",\n' "$index" "$color" >> "$PYWAL_COLORS"
        else
            printf '    "color%d": "%s"\n' "$index" "$color" >> "$PYWAL_COLORS"
        fi
    done
    printf '  }\n}\n' >> "$PYWAL_COLORS"

    # The extension applies this through Firefox's Theme API, which updates
    # every open Zen window without a browser restart.
    "$PYWALFOX_BIN" update >/dev/null 2>&1 || true
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

            if (max >= 55 && saturation >= 0.22 && score > best_score) {
                best_score = score
                best_color = hex
            }
        }

        END { print best_color }
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

DOMINANT_COLOR="$(dominant_color "$IMG" || true)"
mapfile -t BORDER_COLORS < <(sample_wallpaper_colors "$IMG")

if awk -v b="$BRIGHTNESS" 'BEGIN { exit !(b > 0.58) }'; then
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

update_wlogout_icons "$ICON_COLOR"

wallust run "$IMG"

# Match wlogout labels to the wallpaper-aware monochrome icons.
sed -i "s/^@define-color action_foreground .*/@define-color action_foreground $ICON_COLOR;/" \
    "$WLOGOUT_COLORS_FILE"

if [[ "$DOMINANT_COLOR" =~ ^#[[:xdigit:]]{6}$ ]]; then
    ACCENT_RED=$((16#${DOMINANT_COLOR:1:2}))
    ACCENT_GREEN=$((16#${DOMINANT_COLOR:3:2}))
    ACCENT_BLUE=$((16#${DOMINANT_COLOR:5:2}))
    ACCENT_RGB="$ACCENT_RED,$ACCENT_GREEN,$ACCENT_BLUE"

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

    # Glassy application surfaces are always dark. Panel/icon contrast may be
    # black on a bright wallpaper, but Qt text must remain light and readable.
    update_qt_text_color "#F4F6F8" "244,246,248" \
        "$DOMINANT_COLOR" "$ACCENT_RGB" \
        "$SELECTION_TEXT_COLOR" "$SELECTION_TEXT_RGB"
    update_kvantum_svg_accent "$DOMINANT_COLOR"
    update_gtk_theme_accent "$DOMINANT_COLOR"
    update_obsidian_highlights "$DOMINANT_COLOR"
    update_pywalfox_palette "$DOMINANT_COLOR"
    update_kmail_glass_theme "$DOMINANT_COLOR" "$LINK_COLOR" \
        "$ICON_COLOR" "$SELECTION_TEXT_COLOR" "$LINK_RGB"
    refresh_kmail_unread_color_live \
        "$LINK_RED" "$LINK_GREEN" "$LINK_BLUE"

    sed -i "s/^@define-color wallpaper_dominant .*/@define-color wallpaper_dominant $DOMINANT_COLOR;/" \
        "$HOME/.config/waybar/colors.css"
    sed -i "s/^@define-color wallpaper_dominant .*/@define-color wallpaper_dominant $DOMINANT_COLOR;/" \
        "$HOME/.config/wlogout/colors.css"
    sed -i "s/^\\\$wallpaper_dominant = .*/\\\$wallpaper_dominant = rgb(${DOMINANT_COLOR#\#})/" \
        "$HOME/.config/hypr/colors-wallust.conf"

    # Keep Rofi's outline and selection in sync with Waybar's muted accent.
    sed -i \
        -e "s/^[[:space:]]*accent-col: .*/    accent-col: $DOMINANT_COLOR;/" \
        -e "s/^[[:space:]]*accent-soft: .*/    accent-soft: ${DOMINANT_COLOR}66;/" \
        -e "s/^[[:space:]]*sel-bg: .*/    sel-bg: ${DOMINANT_COLOR}D1;/" \
        "$HOME/.config/rofi/colors.rasi"
fi

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

sleep 0.2

reload_kvantum_style
refresh_kmail_folder_counts_live

# These are Hyprland session components. In Plasma, swaync-client would
# D-Bus-activate swaync and make it fight Plasma for the notification name.
killall -SIGUSR2 waybar 2>/dev/null || true
if [[ "${XDG_CURRENT_DESKTOP:-}" != *KDE* ]] && [ -z "${KDE_FULL_SESSION:-}" ] \
    && command -v swaync-client >/dev/null 2>&1; then
    swaync-client -rs >/dev/null 2>&1 || true
fi
hyprctl reload >/dev/null 2>&1 || true
