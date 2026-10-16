#!/bin/bash

DIR="$HOME/Pictures/wallpapers"
STATE_FILE="$HOME/.cache/current_wall_state"

if [ ! -d "$DIR" ]; then
    notify-send "Error" "Folder $DIR not found!"
    exit 1
fi

if [ -f "$STATE_FILE" ]; then
    CURRENT=$(cat "$STATE_FILE")
elif [ -f ~/.config/waypaper/config.ini ]; then
    CURRENT=$(grep '^wallpaper =' ~/.config/waypaper/config.ini | cut -d '=' -f2- | xargs)
    CURRENT="${CURRENT/#\~/$HOME}"
fi

CURRENT_NAME=$(basename "$CURRENT")

shopt -s nullglob nocaseglob
FILES=("$DIR"/*.{jpg,jpeg,png,webp,mp4,webm,mkv,gif})
ARRAY_LENGTH=${#FILES[@]}

if [ $ARRAY_LENGTH -eq 0 ]; then
    notify-send "Error" "There are no supported wallpapers in $DIR!"
    exit 1
fi

INDEX=-1
for i in "${!FILES[@]}"; do
    if [[ "$(basename "${FILES[$i]}")" == "$CURRENT_NAME" ]]; then
        INDEX=$i
        break
    fi
done

NEXT_INDEX=$(( (INDEX + 1) % ARRAY_LENGTH ))
NEXT_WALL="${FILES[$NEXT_INDEX]}"

echo "$NEXT_WALL" > "$STATE_FILE"
mkdir -p "$HOME/.cache/hyprlock"
ln -sfn "$NEXT_WALL" "$HOME/.cache/hyprlock/current_wallpaper"

# Keep the current wallpaper surface alive until apply_wallpaper has prepared
# its replacement. Killing mpvpaper here exposed Swww's last static image
# between two animated wallpapers.
killall -q waypaper 2>/dev/null || true
# Plasma already owns the notification D-Bus interface. Calling swaync-client
# there activates swaync.service, which immediately fails because it cannot take
# that name from Plasma's notification service.
if [[ "${XDG_CURRENT_DESKTOP:-}" != *KDE* ]] && [ -z "${KDE_FULL_SESSION:-}" ] \
    && command -v swaync-client >/dev/null 2>&1; then
    swaync-client -rs >/dev/null 2>&1 || true
fi
sleep 0.2

~/.config/hypr/scripts/apply_wallpaper.sh "$NEXT_WALL" animate

~/.config/hypr/scripts/wall_color.sh "$NEXT_WALL" "$NEXT_WALL"

notify-send "Wallpaper successfully changed" "$(basename "$NEXT_WALL")"
