#!/bin/bash

# Accept "prev" as an argument, otherwise default to next
DIRECTION=$1
[ "$DIRECTION" == "prev" ] && ARG="prev" || ARG="next"

# Get current layout and window state
echo "window_cycle.sh called with ARG=$ARG" >>/tmp/hypr_debug.log
# Get active workspace ID (supports both regular and special workspaces via active window / monitor)
ACTIVE_WIN=$(hyprctl activewindow -j 2>/dev/null)
WS_ID=$(echo "$ACTIVE_WIN" | jq -r '.workspace.id // empty')

if [ -z "$WS_ID" ] || [ "$WS_ID" = "null" ]; then
  SPECIAL_ID=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .specialWorkspace.id // empty')
  if [ -n "$SPECIAL_ID" ] && [ "$SPECIAL_ID" != "0" ] && [ "$SPECIAL_ID" != "null" ]; then
    WS_ID="$SPECIAL_ID"
  fi
fi

if [ -n "$WS_ID" ] && [ "$WS_ID" != "null" ]; then
  LAYOUT=$(hyprctl workspaces -j 2>/dev/null | jq -r --argjson id "$WS_ID" '.[] | select(.id == $id) | .tiledLayout // .layout // empty')
fi

if [ -z "$LAYOUT" ] || [ "$LAYOUT" = "null" ]; then
  LAYOUT=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.tiledLayout // .layout // empty')
fi

if [ -z "$LAYOUT" ] || [ "$LAYOUT" = "null" ]; then
  LAYOUT=$(hyprctl getoption general:layout -j 2>/dev/null | jq -r '.str')
fi
echo "LAYOUT=$LAYOUT" >>/tmp/hypr_debug.log

if [ "$LAYOUT" = "monocle" ]; then
  # Monocle prefers the layout dispatcher for clean stack rotation
  if [ "$ARG" = "next" ]; then
    hyprctl dispatch "hl.dsp.layout('cyclenext')" >/dev/null 2>&1
  else
    hyprctl dispatch "hl.dsp.layout('cycleprev')" >/dev/null 2>&1
  fi
else
  # Dwindle/Scrolling use the standard cyclenext
  if [ "$ARG" = "next" ]; then
    hyprctl dispatch "hl.dsp.window.cycle_next({ next = true })" >/dev/null 2>&1
  else
    hyprctl dispatch "hl.dsp.window.cycle_next({ next = false })" >/dev/null 2>&1
  fi
fi
