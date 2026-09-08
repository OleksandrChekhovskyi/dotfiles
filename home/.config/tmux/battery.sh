#!/bin/sh

# Include spacing only when a battery is present. Report each battery separately.
case $(uname -s) in
    Linux)
        for battery in /sys/class/power_supply/*; do
            [ "$(cat "$battery/type" 2>/dev/null)" = Battery ] || continue
            [ "$(cat "$battery/scope" 2>/dev/null)" != Device ] || continue
            [ "$(cat "$battery/present" 2>/dev/null)" != 0 ] || continue
            capacity=$(cat "$battery/capacity" 2>/dev/null)
            case $capacity in
                ''|*[!0-9]*) continue ;;
            esac
            [ "$capacity" -le 100 ] || continue
            status=$(cat "$battery/status" 2>/dev/null)
            case $status in
                Charging) status=' charging' ;;
                Discharging) status=' discharging' ;;
                Full) status=' full' ;;
                'Not charging') status=' plugged in' ;;
                *) status= ;;
            esac
            printf 'BAT %s%%%s   ' "$capacity" "$status"
        done
        ;;
    Darwin)
        LC_ALL=C pmset -g batt 2>/dev/null | awk -F ';' '
            match($1, /[0-9]+%/) {
                capacity = substr($1, RSTART, RLENGTH)
                status = $2
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
                if (status == "charged") status = "full"
                if (status == "AC attached") status = "plugged in"
                printf "BAT %s%s   ", capacity, (status == "" ? "" : " " status)
            }
        '
        ;;
esac
