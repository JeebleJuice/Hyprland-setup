#!/usr/bin/env bash

human_bytes() {
    awk -v bytes="$1" 'BEGIN {
        split("B KiB MiB GiB TiB", units, " ")
        unit = 1
        while (bytes >= 1024 && unit < 5) { bytes /= 1024; unit++ }
        if (unit < 3) printf "%.0f %s", bytes, units[unit]
        else printf "%.1f %s", bytes, units[unit]
    }'
}

human_rate() { printf '%s/s' "$(human_bytes "$1")"; }

read_cpu() {
    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
    CPU_IDLE=$((idle + iowait))
    CPU_TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))
}

read_cpu
idle_before=$CPU_IDLE
total_before=$CPU_TOTAL
sleep 0.1
read_cpu

total_delta=$((CPU_TOTAL - total_before))
idle_delta=$((CPU_IDLE - idle_before))
if [ "$total_delta" -gt 0 ]; then
    cpu_usage=$(((100 * (total_delta - idle_delta) + total_delta / 2) / total_delta))
else
    cpu_usage=0
fi

# Intel i915 does not expose gpu_busy_percent on every generation. Derive GPU
# activity from inverse RC6 sleep residency and report its current clock. Other
# GPUs simply retain the existing "unavailable" fallback.
gpu_name="Intel GPU"
gpu_usage=""
gpu_freq_mhz=""
gpu_max_freq_mhz=""
for gpu_card in /sys/class/drm/card[0-9]*; do
    [ -r "$gpu_card/device/vendor" ] || continue
    [ "$(<"$gpu_card/device/vendor")" = "0x8086" ] || continue

    gpu_gt="$gpu_card/gt/gt0"
    gpu_rc6_file="$gpu_gt/rc6_residency_ms"
    gpu_freq_file="$gpu_gt/rps_act_freq_mhz"
    gpu_max_freq_file="$gpu_gt/rps_max_freq_mhz"
    [ -r "$gpu_freq_file" ] && gpu_freq_mhz=$(<"$gpu_freq_file")
    [ -r "$gpu_max_freq_file" ] && gpu_max_freq_mhz=$(<"$gpu_max_freq_file")

    if [ -r "$gpu_rc6_file" ]; then
        gpu_rc6_ms=$(<"$gpu_rc6_file")
        gpu_now_ms=$(date +%s%3N)
        gpu_state_file="/tmp/waybar-resource-gpu-${UID}-${gpu_card##*/}"
        if [ -r "$gpu_state_file" ]; then
            read -r gpu_previous_ms gpu_previous_rc6_ms < "$gpu_state_file"
            gpu_elapsed_ms=$((gpu_now_ms - gpu_previous_ms))
            gpu_rc6_delta=$((gpu_rc6_ms - gpu_previous_rc6_ms))
            if [ "$gpu_elapsed_ms" -gt 0 ] && [ "$gpu_rc6_delta" -ge 0 ]; then
                gpu_usage=$((100 - (100 * gpu_rc6_delta + gpu_elapsed_ms / 2) / gpu_elapsed_ms))
                [ "$gpu_usage" -lt 0 ] && gpu_usage=0
                [ "$gpu_usage" -gt 100 ] && gpu_usage=100
            fi
        fi
        printf '%s %s\n' "$gpu_now_ms" "$gpu_rc6_ms" > "$gpu_state_file"
    fi
    break
done

mem_total_kib=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
mem_available_kib=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
swap_total_kib=$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)
swap_free_kib=$(awk '/^SwapFree:/ {print $2}' /proc/meminfo)
mem_used_kib=$((mem_total_kib - mem_available_kib))
swap_used_kib=$((swap_total_kib - swap_free_kib))
mem_percent=$((100 * mem_used_kib / mem_total_kib))
if [ "$swap_total_kib" -gt 0 ]; then
    swap_percent=$((100 * swap_used_kib / swap_total_kib))
else
    swap_percent=0
fi

interface=$(ip route show default 2>/dev/null | awk 'NR == 1 {print $5}')
if [ -z "$interface" ]; then
    for state_file in /sys/class/net/*/operstate; do
        [ "$(<"$state_file")" = "up" ] || continue
        interface=${state_file%/operstate}
        interface=${interface##*/}
        [ "$interface" != "lo" ] && break
    done
fi

rx_rate=0
tx_rate=0
if [ -n "$interface" ] && [ -r "/sys/class/net/$interface/statistics/rx_bytes" ]; then
    rx_bytes=$(<"/sys/class/net/$interface/statistics/rx_bytes")
    tx_bytes=$(<"/sys/class/net/$interface/statistics/tx_bytes")
    now_ns=$(date +%s%N)
    state_file="/tmp/waybar-resource-network-${UID}-$interface"
    if [ -r "$state_file" ]; then
        read -r previous_ns previous_rx previous_tx < "$state_file"
        elapsed_ns=$((now_ns - previous_ns))
        if [ "$elapsed_ns" -gt 0 ]; then
            rx_rate=$(((rx_bytes - previous_rx) * 1000000000 / elapsed_ns))
            tx_rate=$(((tx_bytes - previous_tx) * 1000000000 / elapsed_ns))
            [ "$rx_rate" -lt 0 ] && rx_rate=0
            [ "$tx_rate" -lt 0 ] && tx_rate=0
        fi
    fi
    printf '%s %s %s\n' "$now_ns" "$rx_bytes" "$tx_bytes" > "$state_file"
fi

disk_read_rate=0
disk_write_rate=0
root_source=$(findmnt -no SOURCE / 2>/dev/null)
root_source=${root_source%%\[*}
disk_device=$(lsblk -ndo PKNAME "$root_source" 2>/dev/null)
[ -z "$disk_device" ] && disk_device=${root_source##*/}
disk_stat_file="/sys/block/$disk_device/stat"

if [ -n "$disk_device" ] && [ -r "$disk_stat_file" ]; then
    read -ra disk_stats < "$disk_stat_file"
    sectors_read=${disk_stats[2]}
    sectors_written=${disk_stats[6]}
    now_ns=$(date +%s%N)
    disk_state_file="/tmp/waybar-resource-disk-${UID}-$disk_device"
    if [ -r "$disk_state_file" ]; then
        read -r previous_ns previous_read previous_written < "$disk_state_file"
        elapsed_ns=$((now_ns - previous_ns))
        if [ "$elapsed_ns" -gt 0 ]; then
            disk_read_rate=$(((sectors_read - previous_read) * 512 * 1000000000 / elapsed_ns))
            disk_write_rate=$(((sectors_written - previous_written) * 512 * 1000000000 / elapsed_ns))
            [ "$disk_read_rate" -lt 0 ] && disk_read_rate=0
            [ "$disk_write_rate" -lt 0 ] && disk_write_rate=0
        fi
    fi
    printf '%s %s %s\n' "$now_ns" "$sectors_read" "$sectors_written" > "$disk_state_file"
fi

read -r disk_total disk_used disk_percent < <(
    df -B1 --output=size,used,pcent / | awk 'NR == 2 {gsub("%", "", $3); print $1, $2, $3}'
)

tooltip="CPU: ${cpu_usage}%"
tooltip+=$'\n'
if [ -n "$gpu_usage" ]; then
    tooltip+="GPU active ($gpu_name): ${gpu_usage}%"
elif [ -n "$gpu_freq_mhz" ]; then
    tooltip+="GPU ($gpu_name): sampling…"
else
    tooltip+="GPU: unavailable"
fi
if [ -n "$gpu_freq_mhz" ]; then
    tooltip+=" · ${gpu_freq_mhz}"
    [ -n "$gpu_max_freq_mhz" ] && tooltip+="/${gpu_max_freq_mhz}"
    tooltip+=" MHz"
fi
tooltip+=$'\n'
tooltip+="Memory: $(human_bytes "$((mem_used_kib * 1024))") / $(human_bytes "$((mem_total_kib * 1024))") (${mem_percent}%)"
tooltip+=$'\n'
tooltip+="Swap: $(human_bytes "$((swap_used_kib * 1024))") / $(human_bytes "$((swap_total_kib * 1024))") (${swap_percent}%)"
tooltip+=$'\n'
if [ -n "$interface" ]; then
    tooltip+="Network ($interface): ↓ $(human_rate "$rx_rate")  ↑ $(human_rate "$tx_rate")"
else
    tooltip+="Network: disconnected"
fi
tooltip+=$'\n'
if [ -n "$disk_device" ]; then
    tooltip+="Disk I/O ($disk_device): read $(human_rate "$disk_read_rate")  write $(human_rate "$disk_write_rate")"
else
    tooltip+="Disk I/O: unavailable"
fi
tooltip+=$'\n'
tooltip+="Storage (/): $(human_bytes "$disk_used") / $(human_bytes "$disk_total") (${disk_percent}%)"

jq -cn --arg tooltip "$tooltip" '{text: "", tooltip: $tooltip, class: "resources"}'
