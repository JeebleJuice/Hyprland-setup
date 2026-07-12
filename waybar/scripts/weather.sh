#!/bin/bash

LOCATION="${WEATHER_LOCATION:-Copenhagen}"
LAT="${WEATHER_LAT:-55.6761}"
LON="${WEATHER_LON:-12.5683}"
CACHE="$HOME/.cache/waybar-weather.json"
URL="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&timezone=auto"

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

data=$(curl -fsS --max-time 6 "$URL" 2>/dev/null)

if [ -n "$data" ]; then
    temp=$(printf "%s" "$data" | jq -r '.current.temperature_2m | round')
    feels=$(printf "%s" "$data" | jq -r '.current.apparent_temperature | round')
    humidity=$(printf "%s" "$data" | jq -r '.current.relative_humidity_2m | round')
    wind=$(printf "%s" "$data" | jq -r '.current.wind_speed_10m | round')
    code=$(printf "%s" "$data" | jq -r '.current.weather_code')
    condition=$(weather_label "$code")
    icon=$(icon_for_code "$code")
    tooltip=$(printf "%s\n%s\nFeels like: %s°C\nHumidity: %s%%\nWind: %s km/h" "$LOCATION" "$condition" "$feels" "$humidity" "$wind")

    jq -nc \
        --arg text "$icon ${temp}°C" \
        --arg tooltip "$tooltip" \
        '{text: $text, tooltip: $tooltip, class: "weather"}' | tee "$CACHE"
    exit 0
fi

if [ -f "$CACHE" ]; then
    cat "$CACHE"
else
    jq -nc '{text: "☁ --°", tooltip: "Weather unavailable", class: "weather-error"}'
fi
