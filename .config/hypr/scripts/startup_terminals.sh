!#/bin/bash

# 1. Switch to workspace 8
hyprctl dispatch workspace 8

# 2. Dynamically set the layout to dwindle
hyprctl keyword general:layout dwindle

# 3. Launch the 3 terminals with their respective commands on that workspace
hyprctl dispatch exec "[workspace 8] kitty -e zsh -c 'fastfetch; exec zsh'"
sleep 0.1
hyprctl dispatch exec "[workspace 8] kitty -e cava"
sleep 0.1
hyprctl dispatch layoutmsg "preselect r"
hyprctl dispatch exec "[workspace 8] kitty -e cmatrix"
