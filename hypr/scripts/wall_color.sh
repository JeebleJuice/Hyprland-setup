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

if awk -v b="$BRIGHTNESS" 'BEGIN { exit !(b > 0.58) }'; then
    cat > "$CONTRAST_FILE" <<'EOF'
@define-color module_fg #111111;
@define-color module_border rgba(0, 0, 0, 0.22);
EOF
else
    cat > "$CONTRAST_FILE" <<'EOF'
@define-color module_fg #F4F6F8;
@define-color module_border rgba(255, 255, 255, 0.18);
EOF
fi

wallust run "$IMG"

sleep 0.2

killall -SIGUSR2 waybar
swaync-client -rs
