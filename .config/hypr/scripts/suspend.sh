#!/usr/bin/env bash
MODE="${1:-suspend}"

# 1. Launch lockscreen
bash "$HOME/.config/hypr/scripts/lock.sh" &

# 2. Wait for lockscreen surface to draw
sleep 3.0

# 3. Put machine to sleep
if [[ "$MODE" == "hibernate" ]]; then
    systemctl hibernate
else
    systemctl suspend-then-hibernate
fi
