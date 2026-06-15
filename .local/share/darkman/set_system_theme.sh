#!/bin/bash

THEME=$1

if [ "$THEME" == "light" ]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
elif [ "$THEME" == "dark" ]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
else
    echo "Usage: $0 [light|dark]"
    exit 1
fi
