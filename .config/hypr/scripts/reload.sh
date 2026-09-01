#!/usr/bin/env bash
pkill -f "pactl subscribe" 2>/dev/null || true
qs -p ~/.config/hypr/scripts/quickshell/Shell.qml ipc call main forceReload
