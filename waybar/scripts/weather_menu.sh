#!/usr/bin/env bash

set -u

ROFI_THEME="$HOME/.config/rofi/glass-menu.rasi"
LOCATION="${WEATHER_LOCATION:-Helsingør}"
LAT="${WEATHER_LAT:-56.0361}"
LON="${WEATHER_LON:-12.6136}"
CACHE="$HOME/.cache/waybar-weather-forecast.json"
URL="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max,sunrise,sunset&forecast_days=3&timezone=auto"
TERMINAL_CACHE="$HOME/.cache/waybar-weather-terminal.txt"
FORECAST_SOURCE="live"

weather_label() {
    case "$1" in
        0) printf "Clear" ;;
        1|2) printf "Partly cloudy" ;;
        3) printf "Cloudy" ;;
        45|48) printf "Fog" ;;
        51|53|55|56|57) printf "Drizzle" ;;
        61|63|65|66|67) printf "Rain" ;;
        71|73|75|77) printf "Snow" ;;
        80|81|82) printf "Rain showers" ;;
        85|86) printf "Snow showers" ;;
        95|96|99) printf "Thunderstorm" ;;
        *) printf "Weather" ;;
    esac
}

icon_for_code() {
    case "$1" in
        0) printf "☀" ;;
        1|2) printf "" ;;
        3|45|48) printf "☁" ;;
        51|53|55|56|57|61|63|65|66|67|80|81|82) printf "☔" ;;
        71|73|75|77|85|86) printf "❄" ;;
        95|96|99) printf "" ;;
        *) printf "☁" ;;
    esac
}

fetch_forecast() {
    local temporary="${CACHE}.tmp.$$"
    mkdir -p "$(dirname "$CACHE")"

    if curl -fsS --max-time 10 --retry 2 --retry-delay 1 --retry-all-errors \
        "$URL" -o "$temporary" 2>/dev/null \
        && jq -e '.current.temperature_2m != null and (.daily.time | length) >= 3' \
            "$temporary" >/dev/null 2>&1; then
        mv -f "$temporary" "$CACHE"
        FORECAST_SOURCE="live"
        return 0
    fi

    rm -f "$temporary"
    if [ -s "$CACHE" ] && jq -e '.current and .daily' "$CACHE" >/dev/null 2>&1; then
        FORECAST_SOURCE="cached"
        return 0
    fi
    return 1
}

current_forecast() {
    local code temperature feels humidity wind condition icon suffix=""
    code=$(jq -r '.current.weather_code' "$CACHE")
    temperature=$(jq -r '.current.temperature_2m | round' "$CACHE")
    feels=$(jq -r '.current.apparent_temperature | round' "$CACHE")
    humidity=$(jq -r '.current.relative_humidity_2m | round' "$CACHE")
    wind=$(jq -r '.current.wind_speed_10m | round' "$CACHE")
    condition=$(weather_label "$code")
    icon=$(icon_for_code "$code")
    [ "$FORECAST_SOURCE" = "cached" ] && suffix="  (cached)"

    printf '%s  %s, %s°C\nFeels like %s°C  ·  Humidity %s%%  ·  Wind %s km/h%s\n' \
        "$icon" "$condition" "$temperature" "$feels" "$humidity" "$wind" "$suffix"
}

three_day_forecast() {
    local index date code high low rain wind condition icon day
    for index in 0 1 2; do
        date=$(jq -r ".daily.time[$index]" "$CACHE")
        code=$(jq -r ".daily.weather_code[$index]" "$CACHE")
        high=$(jq -r ".daily.temperature_2m_max[$index] | round" "$CACHE")
        low=$(jq -r ".daily.temperature_2m_min[$index] | round" "$CACHE")
        rain=$(jq -r ".daily.precipitation_probability_max[$index] // 0 | round" "$CACHE")
        wind=$(jq -r ".daily.wind_speed_10m_max[$index] | round" "$CACHE")
        condition=$(weather_label "$code")
        icon=$(icon_for_code "$code")
        day=$(date -d "$date" '+%a %d %b')
        printf '%s  %s  %-15s  %s–%s°C  Rain %s%%  Wind %s km/h\n' \
            "$day" "$icon" "$condition" "$low" "$high" "$rain" "$wind"
    done
    [ "$FORECAST_SOURCE" = "cached" ] && printf '\nCached forecast — the network request failed.\n'
}

show_in_rofi() {
    local title="$1"
    local content="$2"
    printf '%s\n' "$content" | rofi -dmenu -theme "$ROFI_THEME" -p "$title" -no-custom >/dev/null
}

if [ "${1:-}" = "--terminal" ]; then
    terminal_temporary="${TERMINAL_CACHE}.tmp.$$"
    mkdir -p "$(dirname "$TERMINAL_CACHE")"

    # wttr.in's v2d view provides the illustrated terminal forecast.
    if curl -fsSL --max-time 25 --retry 1 --retry-delay 1 \
        "https://v2d.wttr.in/${LOCATION// /+}?m" -o "$terminal_temporary" \
        && [ -s "$terminal_temporary" ]; then
        mv -f "$terminal_temporary" "$TERMINAL_CACHE"
        cat "$TERMINAL_CACHE"
    elif [ -s "$TERMINAL_CACHE" ]; then
        rm -f "$terminal_temporary"
        cat "$TERMINAL_CACHE"
        printf '\nCached forecast — wttr.in is currently unavailable.\n'
    elif fetch_forecast; then
        rm -f "$terminal_temporary"
        printf '\n%s weather\n\n' "$LOCATION"
        current_forecast
        printf '\nThree-day fallback forecast\n\n'
        three_day_forecast
    else
        rm -f "$terminal_temporary"
        printf '\nCould not fetch a forecast and no cached forecast is available.\n'
    fi
    printf '\nPress Enter to close...'
    read -r _
    exit 0
fi

choice=$(printf 'Current forecast\n3 day forecast\nOpen weather in terminal' \
    | rofi -dmenu -theme "$ROFI_THEME" -p "Weather")

case "$choice" in
    "Current forecast")
        if fetch_forecast; then
            show_in_rofi "$LOCATION weather" "$(current_forecast)"
        else
            notify-send "Weather" "Could not fetch a forecast and no cached forecast is available."
        fi
        ;;
    "3 day forecast")
        if fetch_forecast; then
            show_in_rofi "$LOCATION · 3 days" "$(three_day_forecast)"
        else
            notify-send "Weather" "Could not fetch a forecast and no cached forecast is available."
        fi
        ;;
    "Open weather in terminal")
        setsid -f kitty --title "Weather forecast" "$0" --terminal >/dev/null 2>&1 || true
        ;;
esac
