#!/bin/bash

ROFI_THEME="$HOME/.config/rofi/glass-menu.rasi"
LOCATION="${WEATHER_LOCATION:-Helsingør}"

choice=$(printf "Current forecast\n3 day forecast\nOpen weather in terminal" | rofi -dmenu -theme "$ROFI_THEME" -p "Weather")

show_weather() {
    url="$1"
    title="$2"
    if command -v curl >/dev/null 2>&1; then
        text=$(curl -fsS --max-time 5 "$url" 2>/dev/null)
        if [ -n "$text" ]; then
            printf "%s\n" "$text" | rofi -dmenu -theme "$ROFI_THEME" -p "$title"
        else
            notify-send "Weather" "Could not fetch forecast"
        fi
    else
        notify-send "Weather" "curl is not installed"
    fi
}

case "$choice" in
    "Current forecast")
        show_weather "https://wttr.in/${LOCATION}?format=3" "Weather"
        ;;
    "3 day forecast")
        show_weather "https://wttr.in/${LOCATION}?format=%l:+%c+%t+%w+%m" "Forecast"
        ;;
    "Open weather in terminal")
        kitty -e sh -c "curl -fsS 'https://wttr.in/${LOCATION}'; printf '\nPress enter to close...'; read -r _"
        ;;
esac
