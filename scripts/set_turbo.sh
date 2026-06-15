#!/bin/bash

# Path to the intel_pstate turbo control
TURBO_PATH="/sys/devices/system/cpu/intel_pstate/no_turbo"

# Check if the path exists (ensure intel_pstate is in use)
if [ ! -f "$TURBO_PATH" ]; then
    echo "Error: $TURBO_PATH not found. Ensure the intel_pstate driver is active."
    exit 1
fi

# Function to display usage
usage() {
    echo "Usage: sudo $0 {on|off}"
    exit 1
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)."
  exit 1
fi

# Logic based on argument
case "$1" in
    on)
        echo 0 > "$TURBO_PATH"
        echo "Turbo Boost ENABLED (no_turbo = 0)"
        ;;
    off)
        echo 1 > "$TURBO_PATH"
        echo "Tur#!/bin/bash

# Path to the intel_pstate turbo control
TURBO_PATH="/sys/devices/system/cpu/intel_pstate/no_turbo"

# Check if the path exists (ensure intel_pstate is in use)
if [ ! -f "$TURBO_PATH" ]; then
    echo "Error: $TURBO_PATH not found. Ensure the intel_pstate driver is active."
    exit 1
fi

# Function to display usage
usage() {
    echo "Usage: sudo $0 {on|off}"
    exit 1
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)."
  exit 1
fi

# Logic based on argument
case "$1" in
    on)
        echo 0 > "$TURBO_PATH"
        echo "Turbo Boost ENABLED (no_turbo = 0)"
        ;;
    off)
        echo 1 > "$TURBO_PATH"
        echo "Turbo Boost DISABLED (no_turbo = 1)"
        ;;
    *)
        usage
        ;;
esacbo Boost DISABLED (no_turbo = 1)"
        ;;
    *)
        usage
        ;;
esac