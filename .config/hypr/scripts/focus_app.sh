#!/usr/bin/env bash
# Focus an application window using Hyprland 0.55+ Lua API

TARGET="$1"
if [ -z "$TARGET" ]; then exit 0; fi

SAN=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9_\-]//g')
if [ -z "$SAN" ]; then exit 0; fi

MATCH=$(hyprctl clients -j 2>/dev/null | jq -r --arg t "$SAN" '.[] | select((.class? != null and (.class | test($t; "i"))) or (.initialClass? != null and (.initialClass | test($t; "i"))) or (.title? != null and (.title | test($t; "i")))) | "\(.workspace.id) \(.address)"' | head -n1)

if [ -n "$MATCH" ]; then
    WS=$(echo "$MATCH" | awk '{print $1}')
    ADDR=$(echo "$MATCH" | awk '{print $2}')
    if [ "$WS" != "null" ] && [ -n "$WS" ]; then
        hyprctl dispatch "hl.dsp.focus({ workspace = $WS })" >/dev/null 2>&1
    fi
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$ADDR\" })" >/dev/null 2>&1
else
    gtk-launch "$SAN" >/dev/null 2>&1 || xdg-open "$SAN" >/dev/null 2>&1 &
fi

~/.config/hypr/scripts/qs_manager.sh close >/dev/null 2>&1 &
