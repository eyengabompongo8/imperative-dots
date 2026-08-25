#!/bin/bash
# Script to enable or disable CPU Turbo Boost

# Path to the intel_pstate turbo control
TURBO_PATH="/sys/devices/system/cpu/intel_pstate/no_turbo"
AMD_BOOST_PATH="/sys/devices/system/cpu/cpufreq/boost"

TARGET_PATH=""
if [ -f "$TURBO_PATH" ]; then
    TARGET_PATH="$TURBO_PATH"
elif [ -f "$AMD_BOOST_PATH" ]; then
    TARGET_PATH="$AMD_BOOST_PATH"
else
    echo "Error: No supported CPU turbo boost control found." >&2
    exit 1
fi

usage() {
    echo "Usage: sudo $0 {on|off}" >&2
    exit 1
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)." >&2
    exit 1
fi

case "$1" in
    on)
        if [ "$TARGET_PATH" = "$TURBO_PATH" ]; then
            echo 0 > "$TURBO_PATH"
            echo "Turbo Boost ENABLED (no_turbo = 0)"
        else
            echo 1 > "$AMD_BOOST_PATH"
            echo "Turbo Boost ENABLED (boost = 1)"
        fi
        ;;
    off)
        if [ "$TARGET_PATH" = "$TURBO_PATH" ]; then
            echo 1 > "$TURBO_PATH"
            echo "Turbo Boost DISABLED (no_turbo = 1)"
        else
            echo 0 > "$AMD_BOOST_PATH"
            echo "Turbo Boost DISABLED (boost = 0)"
        fi
        ;;
    *)
        usage
        ;;
esac
