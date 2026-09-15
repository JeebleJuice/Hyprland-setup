#!/bin/bash
IMG="$1"

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

DOMINANT_COLOR="$(dominant_color "$IMG" || true)"

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
    sed -i "s/^@define-color wallpaper_dominant .*/@define-color wallpaper_dominant $DOMINANT_COLOR;/" \
        "$HOME/.config/waybar/colors.css"
    sed -i "s/^@define-color wallpaper_dominant .*/@define-color wallpaper_dominant $DOMINANT_COLOR;/" \
        "$HOME/.config/wlogout/colors.css"

    # Keep Rofi menus in sync with Waybar's muted accent.
    sed -i \
        -e "s/^[[:space:]]*accent-col: .*/    accent-col: $DOMINANT_COLOR;/" \
        -e "s/^[[:space:]]*accent-soft: .*/    accent-soft: ${DOMINANT_COLOR}66;/" \
        -e "s/^[[:space:]]*sel-bg: .*/    sel-bg: ${DOMINANT_COLOR}D1;/" \
        "$HOME/.config/rofi/colors.rasi"
fi

sleep 0.2

killall -SIGUSR2 waybar
swaync-client -rs
