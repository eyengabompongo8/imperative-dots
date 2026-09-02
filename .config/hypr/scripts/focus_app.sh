#!/usr/bin/env bash
# Focus application window using Hyprland 0.55+ Lua API with PID ancestry & smart matching

APP_NAME="$1"
DESKTOP_ENTRY="$2"
SENDER_PID="$3"
SUMMARY="$4"

CLIENTS=$(hyprctl clients -j 2>/dev/null)
if [ -z "$CLIENTS" ] || [ "$CLIENTS" = "[]" ]; then
    TARGET="${DESKTOP_ENTRY:-$APP_NAME}"
    if [ -n "$TARGET" ]; then
        gtk-launch "$TARGET" >/dev/null 2>&1 || xdg-open "$TARGET" >/dev/null 2>&1 &
    fi
    ~/.config/hypr/scripts/qs_manager.sh close >/dev/null 2>&1 &
    exit 0
fi

MATCH_ADDR=""
MATCH_WS=""

# 1. Tier 1: Direct PID Ancestry Matching (if SENDER_PID provided)
if [ -n "$SENDER_PID" ] && [ "$SENDER_PID" -gt 1 ] 2>/dev/null; then
    CUR_PID="$SENDER_PID"
    while [ -n "$CUR_PID" ] && [ "$CUR_PID" -gt 1 ] 2>/dev/null; do
        MATCH=$(echo "$CLIENTS" | jq -r --argjson p "$CUR_PID" '
            [ .[] | select(.pid == $p) ]
            | sort_by(.focusHistoryID // 99)
            | .[0]
            | if . != null then "\(.workspace.id) \(.address)" else empty end
        ')
        if [ -n "$MATCH" ]; then
            MATCH_WS=$(echo "$MATCH" | awk '{print $1}')
            MATCH_ADDR=$(echo "$MATCH" | awk '{print $2}')
            break
        fi
        if [ -f "/proc/$CUR_PID/stat" ]; then
            CUR_PID=$(awk '{print $4}' "/proc/$CUR_PID/stat" 2>/dev/null)
        else
            CUR_PID=$(ps -o ppid= -p "$CUR_PID" 2>/dev/null | tr -d ' ')
        fi
    done
fi

# 2. Tier 2: Fallback to App Name / Desktop Entry / Alias / Title Matching
if [ -z "$MATCH_ADDR" ]; then
    TARGET="${DESKTOP_ENTRY:-$APP_NAME}"
    if [ -n "$TARGET" ]; then
        SAN=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9_\-]//g')
        if [ -n "$SAN" ]; then
            MATCH=$(echo "$CLIENTS" | jq -r --arg t "$SAN" --arg sum "$SUMMARY" '
                def norm(s): (s // "") | ascii_downcase;
                def alias_match(s; t):
                    norm(s) as $s | norm(t) as $t |
                    if $t == "" or $s == "" then false
                    elif $s == $t then true
                    elif ($s | contains($t)) or ($t | contains($s)) then true
                    elif ($t == "antigravity" and ($s | contains("agy"))) or ($t == "agy" and ($s | contains("antigravity"))) then true
                    elif ($t == "neovim" and ($s | contains("nvim"))) or ($t == "nvim" and ($s | contains("neovim"))) then true
                    else false
                    end;

                [ .[] | 
                  . as $c |
                  (if alias_match($c.class; $t) then 100
                   elif alias_match($c.initialClass; $t) then 80
                   elif alias_match($c.title; $t) then 60
                   elif alias_match($c.initialTitle; $t) then 40
                   elif ($sum != "" and alias_match($c.title; $sum)) then 50
                   else 0 end) as $match_score |
                  select($match_score > 0) |
                  {
                    ws_id: .workspace.id,
                    address: .address,
                    score: ($match_score - (.focusHistoryID // 99))
                  }
                ]
                | sort_by(-.score)
                | .[0]
                | if . != null then "\(.ws_id) \(.address)" else empty end
            ')
            if [ -n "$MATCH" ]; then
                MATCH_WS=$(echo "$MATCH" | awk '{print $1}')
                MATCH_ADDR=$(echo "$MATCH" | awk '{print $2}')
            fi
        fi
    fi
fi

# 3. Focus Window in Hyprland or Fallback to Launch
if [ -n "$MATCH_ADDR" ]; then
    if [ "$MATCH_WS" != "null" ] && [ -n "$MATCH_WS" ] && [ "$MATCH_WS" -gt 0 ] 2>/dev/null; then
        hyprctl dispatch "hl.dsp.focus({ workspace = $MATCH_WS })" >/dev/null 2>&1
    fi
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$MATCH_ADDR\" })" >/dev/null 2>&1
else
    TARGET="${DESKTOP_ENTRY:-$APP_NAME}"
    if [ -n "$TARGET" ]; then
        SAN=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9_\-]//g')
        if [ -n "$SAN" ]; then
            gtk-launch "$SAN" >/dev/null 2>&1 || xdg-open "$SAN" >/dev/null 2>&1 &
        fi
    fi
fi

~/.config/hypr/scripts/qs_manager.sh close >/dev/null 2>&1 &
