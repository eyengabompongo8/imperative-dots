#!/bin/bash

CURRENT_WORKSPACE=$(hyprctl monitors -j | jq -r '(.[] | select(.focused) | .specialWorkspace.name) // "" | if . == "" then "not_special" else . end')

ACTION_TYPE=$1
ACTION=$2

if [[ $ACTION_TYPE == "toggle" ]]; then

  if [[ $ACTION == "spotify_discord" ]]; then

    hyprctl dispatch "hl.dispatch(hl.dsp.workspace.toggle_special('spotify_discord'))"

  elif [[ $ACTION == "monitoring" ]]; then

    hyprctl dispatch "hl.dispatch(hl.dsp.workspace.toggle_special('monitoring'))"

  else

    echo "Invalid workspace: ${ACTION}. Valid workspaces: spotify_discord, monitoring"

  fi

elif [[ $ACTION_TYPE == "move" ]]; then

  if [[ $ACTION == "up" ]]; then

    if [[ $CURRENT_WORKSPACE == "special:spotify_discord" ]]; then

      hyprctl dispatch "hl.dispatch(hl.dsp.workspace.toggle_special('spotify_discord'))"

    elif [[ $CURRENT_WORKSPACE == "not_special" ]]; then

      hyprctl dispatch "hl.dispatch(hl.dsp.workspace.toggle_special('monitoring'))"

    elif [[ $CURRENT_WORKSPACE == "special:monitoring" ]]; then

      echo "Already at the uppermost workspace: ${CURRENT_WORKSPACE}"

    else

      echo "Invalid move: ${ACTION}. Valid moves: up, down"

    fi

  elif [[ $ACTION == "down" ]]; then

    if [[ $CURRENT_WORKSPACE == "special:monitoring" ]]; then

      hyprctl dispatch "hl.dispatch(hl.dsp.workspace.toggle_special('monitoring'))"

    elif [[ $CURRENT_WORKSPACE == "not_special" ]]; then

      hyprctl dispatch "hl.dispatch(hl.dsp.workspace.toggle_special('spotify_discord'))"

    elif [[ $CURRENT_WORKSPACE == "special:spotify_discord" ]]; then

      echo "Already at the bottommost workspace: ${CURRENT_WORKSPACE}"

    else

      echo "Invalid move: ${ACTION}. Valid moves: up, down"

    fi

  fi

else

  echo "Invalid action: ${ACTION_TYPE}. Valid actions: toggle, move"

fi
