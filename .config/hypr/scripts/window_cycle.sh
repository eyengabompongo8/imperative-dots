#!/bin/bash

# Accept "prev" as an argument, otherwise default to next
DIRECTION=$1
[ "$DIRECTION" == "prev" ] && ARG="prev" || ARG="next"

# Get current layout and window state
ACTIVE_DATA=$(hyprctl activeworkspace -j)
LAYOUT=$(echo "$ACTIVE_DATA" | jq -r '.tiledLayout')
FS_STATE=$(hyprctl activewindow -j | jq -r '.fullscreen')

if [ "$LAYOUT" = "monocle" ]; then
    # Monocle prefers the layoutmsg dispatcher for clean stack rotation
    hyprctl dispatch layoutmsg cycle$ARG
else
    # Dwindle/Master use the standard cyclenext
    # The 'prev' argument for cyclenext is literally the word 'prev'
    hyprctl dispatch cyclenext $ARG
fi
