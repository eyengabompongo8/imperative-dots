#!/bin/bash

# Silent window cycling for gestures & non-monocle layouts
DIRECTION="${1:-next}"
[ "$DIRECTION" == "prev" ] && ARG="prev" || ARG="next"

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

if [ "$LAYOUT" = "monocle" ]; then
  # Monocle layout: cycle through ALL windows on the workspace (both tiled and floating)
  ACTIVE_ADDR=$(echo "$ACTIVE_WIN" | jq -r '.address // empty' | tr '[:upper:]' '[:lower:]')
  CLIENTS=$(hyprctl clients -j 2>/dev/null)

  TARGET_ADDR=$(echo "$CLIENTS" | jq -r --argjson ws "$WS_ID" --arg act "$ACTIVE_ADDR" --arg dir "$ARG" '
    [ .[] | select((.workspace.id == $ws) and (.mapped == true) and (.hidden != true)) ] as $wins
    | ($wins | length) as $len
    | if $len <= 1 then empty
      else
        ($wins | map(.address | ascii_downcase)) as $addrs
        | ($addrs | index($act) // 0) as $cur_idx
        | if $dir == "prev" then
            $wins[(($cur_idx - 1 + $len) % $len)].address
          else
            $wins[(($cur_idx + 1) % $len)].address
          end
      end
  ')
  if [ -n "$TARGET_ADDR" ] && [ "$TARGET_ADDR" != "null" ]; then
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$TARGET_ADDR\" })" >/dev/null 2>&1
  fi
elif [ "$LAYOUT" = "scrolling" ]; then
  # Scrolling layout: geometric cycle across columns (X) and stacked windows (Y)
  ACTIVE_ADDR=$(echo "$ACTIVE_WIN" | jq -r '.address // empty' | tr '[:upper:]' '[:lower:]')
  CLIENTS=$(hyprctl clients -j 2>/dev/null)

  TARGET_ADDR=$(echo "$CLIENTS" | jq -r --argjson ws "$WS_ID" --arg act "$ACTIVE_ADDR" --arg dir "$ARG" '
    [ .[] | select((.workspace.id == $ws) and (.mapped == true) and (.hidden != true)) ]
    | sort_by(.at[0], .at[1]) as $wins
    | ($wins | length) as $len
    | if $len <= 1 then empty
      else
        ($wins | map(.address | ascii_downcase)) as $addrs
        | ($addrs | index($act) // 0) as $cur_idx
        | if $dir == "prev" then
            $wins[(($cur_idx - 1 + $len) % $len)].address
          else
            $wins[(($cur_idx + 1) % $len)].address
          end
      end
  ')
  if [ -n "$TARGET_ADDR" ] && [ "$TARGET_ADDR" != "null" ]; then
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$TARGET_ADDR\" })" >/dev/null 2>&1
  fi
else
  # Dwindle/Master or generic layout window cycle
  if [ "$ARG" = "next" ]; then
    hyprctl dispatch "hl.dsp.window.cycle_next({ next = true })" >/dev/null 2>&1
  else
    hyprctl dispatch "hl.dsp.window.cycle_next({ next = false })" >/dev/null 2>&1
  fi
fi
