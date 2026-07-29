#!/bin/bash

sleep 2

# 1. Switch to workspace 0
hyprctl dispatch workspace 8

# 2. Dynamically set the layout to dwindle
sleep 0.3
hyprctl keyword general:layout "dwindle"

# 3. Launch the 3 terminals with their respective commands on that workspace
sleep 0.3
hyprctl dispatch exec "[workspace 8] kitty -e zsh -c 'fastfetch; exec zsh'"
hyprctl dispatch layoutmsg "preselect r"
sleep 0.3
hyprctl dispatch exec "[workspace 8] kitty -e cava"
sleep 0.3
hyprctl dispatch layoutmsg "preselect d"
hyprctl dispatch exec "[workspace 8] kitty -e cmatrix"
