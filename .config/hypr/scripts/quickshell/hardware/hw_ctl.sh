#!/usr/bin/env bash
# Hardware controller for Quickshell
# Directly queries Linux sysfs without any caching or emulation.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAT_THRESH_SCRIPT="$SCRIPT_DIR/set_battery_threshold.sh"
TURBO_SCRIPT="$SCRIPT_DIR/set_turbo.sh"

ACTION="$1"
VALUE="$2"

get_info() {
    local has_bat=false
    local bat_thresh=100
    local has_turbo=false
    local turbo_state="off"

    # Direct live query of battery charge control end threshold
    local bat_file
    bat_file=$(ls /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -n 1)
    if [ -n "$bat_file" ]; then
        local raw_val
        raw_val=$(cat "$bat_file" 2>/dev/null)
        if [[ "$raw_val" =~ ^[0-9]+$ ]] && [ "$raw_val" -ge 1 ] && [ "$raw_val" -le 100 ]; then
            has_bat=true
            bat_thresh="$raw_val"
        fi
    fi

    # Direct live query of CPU turbo state
    if [ -f "/sys/devices/system/cpu/intel_pstate/no_turbo" ]; then
        has_turbo=true
        local val
        val=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null)
        if [ "$val" = "0" ]; then
            turbo_state="on"
        else
            turbo_state="off"
        fi
    elif [ -f "/sys/devices/system/cpu/cpufreq/boost" ]; then
        has_turbo=true
        local val
        val=$(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null)
        if [ "$val" = "1" ]; then
            turbo_state="on"
        else
            turbo_state="off"
        fi
    fi

    cat <<EOF
{
  "hasBatteryThreshold": $has_bat,
  "batteryThreshold": $bat_thresh,
  "hasTurbo": $has_turbo,
  "turbo": "$turbo_state"
}
EOF
}

case "$ACTION" in
    get)
        get_info
        ;;
    set-battery)
        PASS=$(cat -)
        if [ -z "$VALUE" ] || ! [[ "$VALUE" =~ ^[0-9]+$ ]] || [ "$VALUE" -lt 50 ] || [ "$VALUE" -gt 100 ]; then
            echo '{"success":false,"error":"Threshold must be between 50 and 100."}'
            exit 1
        fi
        
        OUT=$(echo "$PASS" | sudo -S -k bash "$BAT_THRESH_SCRIPT" "$VALUE" 2>&1)
        STATUS=$?
        if [ $STATUS -eq 0 ]; then
            echo "{\"success\":true,\"msg\":\"Battery charge threshold set to ${VALUE}%\"}"
        else
            CLEAN_OUT=$(echo "$OUT" | grep -v '\[sudo\]' | tr '\n' ' ' | sed 's/"/\\"/g')
            [ -z "$CLEAN_OUT" ] && CLEAN_OUT="Authentication failed."
            echo "{\"success\":false,\"error\":\"$CLEAN_OUT\"}"
        fi
        ;;
    set-turbo)
        PASS=$(cat -)
        if [ "$VALUE" != "on" ] && [ "$VALUE" != "off" ]; then
            echo '{"success":false,"error":"Invalid turbo argument. Use on or off."}'
            exit 1
        fi
        
        OUT=$(echo "$PASS" | sudo -S -k bash "$TURBO_SCRIPT" "$VALUE" 2>&1)
        STATUS=$?
        if [ $STATUS -eq 0 ]; then
            echo "{\"success\":true,\"msg\":\"Turbo boost turned ${VALUE}\"}"
        else
            CLEAN_OUT=$(echo "$OUT" | grep -v '\[sudo\]' | tr '\n' ' ' | sed 's/"/\\"/g')
            [ -z "$CLEAN_OUT" ] && CLEAN_OUT="Authentication failed."
            echo "{\"success\":false,\"error\":\"$CLEAN_OUT\"}"
        fi
        ;;
    *)
        echo '{"error":"Usage: hw_ctl.sh {get|set-battery <val>|set-turbo <on|off>}"}'
        exit 1
        ;;
esac
