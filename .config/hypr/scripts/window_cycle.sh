#!/bin/bash

# Accept "prev" as an argument, otherwise default to next
DIRECTION=$1
[ "$DIRECTION" == "prev" ] && ARG="prev" || ARG="next"

# Get current layout and window state
echo "window_cycle.sh called with ARG=$ARG" >>/tmp/hypr_debug.log
LAYOUT=$(hyprctl getoption general:layout -j | jq -r '.str')
echo "LAYOUT=$LAYOUT" >>/tmp/hypr_debug.log
FS_STATE=$(hyprctl activewindow -j | jq -r '.fullscreen')
echo "FS_STATE=$FS_STATE" >>/tmp/hypr_debug.log

if [ "$LAYOUT" = "monocle" ]; then
  # Monocle prefers the layout dispatcher for clean stack rotation
  if [ "$ARG" = "next" ]; then
    hyprctl dispatch "hl.dsp.layout('cyclenext')" >/dev/null 2>&1
  else
    hyprctl dispatch "hl.dsp.layout('cycleprev')" >/dev/null 2>&1
  fi
else
  # Dwindle/Master use the standard cyclenext
  if [ "$ARG" = "next" ]; then
    hyprctl dispatch "hl.dsp.window.cycle_next({ next = true })" >/dev/null 2>&1
  else
    hyprctl dispatch "hl.dsp.window.cycle_next({ next = false })" >/dev/null 2>&1
  fi
fi
