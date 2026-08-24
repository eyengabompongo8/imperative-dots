#!/bin/bash
LAYOUT_NAME=$1
if [ -z "$LAYOUT_NAME" ]; then
  exit 1
fi

# 1. Check active window workspace name
ACTIVE_WIN=$(hyprctl activewindow -j 2>/dev/null)
WS_NAME=$(echo "$ACTIVE_WIN" | jq -r '.workspace.name // empty')

# 2. Check focused monitor special workspace name
if [ -z "$WS_NAME" ] || [ "$WS_NAME" = "null" ]; then
  SPECIAL_NAME=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .specialWorkspace.name // empty')
  if [ -n "$SPECIAL_NAME" ] && [ "$SPECIAL_NAME" != "null" ]; then
    WS_NAME="$SPECIAL_NAME"
  fi
fi

# 3. Fallback to active workspace name
if [ -z "$WS_NAME" ] || [ "$WS_NAME" = "null" ]; then
  WS_NAME=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.name // empty')
fi

if [ -n "$WS_NAME" ] && [ "$WS_NAME" != "null" ]; then
  hyprctl eval "hl.workspace_rule({ workspace = \"$WS_NAME\", layout = \"$LAYOUT_NAME\" })" >/dev/null 2>&1
fi
