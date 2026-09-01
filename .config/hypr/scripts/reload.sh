#!/usr/bin/env bash
pkill -f "pactl subscribe" 2>/dev/null || true
if pgrep -f "quickshell -p" > /dev/null 2>&1; then
    qs -p ~/.config/hypr/scripts/quickshell/Shell.qml ipc call main forceReload
else
    systemd-run --user --unit=quickshell-session quickshell -p "$HOME/.config/hypr/scripts/quickshell/Shell.qml" >/dev/null 2>&1 || nohup quickshell -p "$HOME/.config/hypr/scripts/quickshell/Shell.qml" > /dev/null 2>&1 &
fi
