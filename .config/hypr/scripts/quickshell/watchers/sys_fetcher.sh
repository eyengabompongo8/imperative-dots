#!/usr/bin/env bash

# State file for lightweight, delta-based stats across ticks
STATE_FILE="${QS_CACHE_SYSDATA:-${XDG_RUNTIME_DIR:-/tmp}}/quickshell_sys_state"
NOW=$(date +%s%N)

# 1. Read current CPU counters directly using bash read
read -r _ u n s i io ir so st g gn < /proc/stat
IDLE=$i
TOTAL=$((u + n + s + i + io + ir + so + st))

# 2. Read network dev counters using awk
read -r rx tx < <(awk -v IGNORECASE=1 '/^ *[ew]/{rx+=$2; tx+=$10} END{print rx, tx}' /proc/net/dev)

# 3. Read physical disk sectors (512 bytes each) using awk
read -r disk_r disk_w < <(awk '{dev=$3; if (dev ~ /^(sd[a-z]+|nvme[0-9]+n[0-9]+|vd[a-z]+|mmcblk[0-9]+|xvd[a-z]+)$/) {r+=$6; w+=$10}} END {print r*512, w*512}' /proc/diskstats)

# 4. Read memory info directly using bash
TOTAL_MEM=0
AVAIL_MEM=0
while IFS=":" read -r key val; do
    case "$key" in
        MemTotal) TOTAL_MEM=${val//[!0-9]/} ;;
        MemAvailable) AVAIL_MEM=${val//[!0-9]/} ;;
    esac
    if [ $TOTAL_MEM -gt 0 ] && [ $AVAIL_MEM -gt 0 ]; then
        break
    fi
done < /proc/meminfo

USED_MEM=$((TOTAL_MEM - AVAIL_MEM))
if [ "$TOTAL_MEM" -gt 0 ]; then
    RAM_PCT=$(( 100 * USED_MEM / TOTAL_MEM ))
    RAM_GB=$(( USED_MEM / 1048576 ))
    RAM_GB_DEC=$(( (USED_MEM * 10 / 1048576) % 10 ))
    RAM_GB_STR="${RAM_GB}.${RAM_GB_DEC}"
else
    RAM_PCT=0
    RAM_GB_STR="0.0"
fi

# 5. Temperature calculation
TEMP_RAW=""
for hwmon in /sys/class/hwmon/hwmon*; do
    if [ -f "$hwmon/name" ]; then
        hwmon_name=$(cat "$hwmon/name" 2>/dev/null)
        if [[ "$hwmon_name" =~ ^(coretemp|k10temp|zenpower|cpu_thermal|bcm2835_thermal)$ ]]; then
            if [ -f "$hwmon/temp1_input" ]; then
                TEMP_RAW=$(cat "$hwmon/temp1_input" 2>/dev/null)
                break
            fi
        fi
    fi
done

if [ -z "$TEMP_RAW" ]; then
    for tz in /sys/class/thermal/thermal_zone*; do
        if [ -f "$tz/type" ]; then
            tz_type=$(cat "$tz/type" 2>/dev/null)
            if [[ "$tz_type" =~ ^(x86_pkg_temp|cpu_thermal|cpu-thermal)$ ]]; then
                TEMP_RAW=$(cat "$tz/temp" 2>/dev/null)
                break
            fi
        fi
    done
fi

if [ -z "$TEMP_RAW" ]; then
    TEMP_RAW=$(cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
fi

if [ "$TEMP_RAW" -gt 1000 ]; then
    TEMP=$((TEMP_RAW / 1000))
else
    TEMP=$TEMP_RAW
fi

# 6. Compute deltas from previous tick
if [ -f "$STATE_FILE" ]; then
    read -r prev_time prev_total prev_idle prev_rx prev_tx prev_dr prev_dw < "$STATE_FILE"
    
    time_diff_ms=$(( (NOW - prev_time) / 1000000 ))
    if [ "$time_diff_ms" -gt 100 ]; then
        diff_total=$((TOTAL - prev_total))
        diff_idle=$((IDLE - prev_idle))
        if [ "$diff_total" -gt 0 ]; then
            CPU_USAGE=$(( 100 * (diff_total - diff_idle) / diff_total ))
        else
            CPU_USAGE=0
        fi
        
        RX_RATE=$(( (rx - prev_rx) * 1000 / time_diff_ms ))
        TX_RATE=$(( (tx - prev_tx) * 1000 / time_diff_ms ))
        DISK_RATE=$(( ((disk_r - prev_dr) + (disk_w - prev_dw)) * 1000 / time_diff_ms ))
    else
        CPU_USAGE=0
        RX_RATE=0
        TX_RATE=0
        DISK_RATE=0
    fi
else
    CPU_USAGE=0
    RX_RATE=0
    TX_RATE=0
    DISK_RATE=0
fi

# Save state for next tick
echo "$NOW $TOTAL $IDLE $rx $tx $disk_r $disk_w" > "$STATE_FILE"

# Sanitize lower bounds
[ "$CPU_USAGE" -lt 0 ] && CPU_USAGE=0
[ "$RX_RATE" -lt 0 ] && RX_RATE=0
[ "$TX_RATE" -lt 0 ] && TX_RATE=0
[ "$DISK_RATE" -lt 0 ] && DISK_RATE=0

# Format: CPU|RAM_PCT|RAM_GB|TEMP|RX_RATE|TX_RATE|DISK_RATE
echo "$CPU_USAGE|$RAM_PCT|$RAM_GB_STR|$TEMP|$RX_RATE|$TX_RATE|$DISK_RATE"
