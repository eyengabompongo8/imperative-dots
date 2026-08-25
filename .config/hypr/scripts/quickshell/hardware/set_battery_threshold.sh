#!/usr/bin/env bash
# Script to set battery charging threshold

THRESHOLD=$1
BAT_FILE=$(ls /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -n 1)

if [ -z "$BAT_FILE" ]; then
    echo "Error: Battery charge threshold file not found." >&2
    exit 1
fi

if [ -z "$THRESHOLD" ] || ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || [ "$THRESHOLD" -lt 50 ] || [ "$THRESHOLD" -gt 100 ]; then
    echo "Error: Threshold must be an integer between 50 and 100." >&2
    exit 1
fi

echo "Setting battery limit to ${THRESHOLD}%..."
echo "$THRESHOLD" | sudo tee "$BAT_FILE" > /dev/null
echo "Done! Battery charge limit set to ${THRESHOLD}%."
