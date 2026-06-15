#!/usr/bin/env bash
# Script for modern Samsung Galaxy Books

THRESHOLD=$1
BAT_FILE=$(ls /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -n 1)

if [ -z "$BAT_FILE" ]; then
    echo "Error: Standard threshold file not found." >&2
    exit 1
fi

echo "Setting battery limit to ${THRESHOLD}%..."
echo "$THRESHOLD" | sudo tee "$BAT_FILE" > /dev/null
echo "Done!"