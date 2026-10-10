#!/bin/bash

THEME=$1

if [ "$THEME" == "light" ]; then
  # Change System Color Scheme
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Light' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-light' 2>/dev/null || true

  # GTK4 / Libadwaita Styling
  mkdir -p "$HOME/.config/gtk-4.0"
  if [ -d "$HOME/.themes/WhiteSur-Light/gtk-4.0" ]; then
    cp -a "$HOME/.themes/WhiteSur-Light/gtk-4.0/"* "$HOME/.config/gtk-4.0/"
  fi

  sed -i 's/gtk-theme-name=.*/gtk-theme-name=WhiteSur-Light/' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
  sed -i 's/gtk-icon-theme-name=.*/gtk-icon-theme-name=WhiteSur-light/' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
  sed -i 's/gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=0/' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true

  sed -i 's/gtk-theme-name=.*/gtk-theme-name=WhiteSur-Light/' "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null || true
  sed -i 's/gtk-icon-theme-name=.*/gtk-icon-theme-name=WhiteSur-light/' "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null || true
  sed -i 's/gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=0/' "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null || true

elif [ "$THEME" == "dark" ]; then
  # Change System Color Scheme
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark' 2>/dev/null || true

  # GTK4 / Libadwaita Styling
  mkdir -p "$HOME/.config/gtk-4.0"
  if [ -d "$HOME/.themes/WhiteSur-Dark/gtk-4.0" ]; then
    cp -a "$HOME/.themes/WhiteSur-Dark/gtk-4.0/"* "$HOME/.config/gtk-4.0/"
  fi

  sed -i 's/gtk-theme-name=.*/gtk-theme-name=WhiteSur-Dark/' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
  sed -i 's/gtk-icon-theme-name=.*/gtk-icon-theme-name=WhiteSur-dark/' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
  sed -i 's/gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=1/' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true

  sed -i 's/gtk-theme-name=.*/gtk-theme-name=WhiteSur-Dark/' "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null || true
  sed -i 's/gtk-icon-theme-name=.*/gtk-icon-theme-name=WhiteSur-dark/' "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null || true
  sed -i 's/gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=1/' "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null || true
else
  echo "Usage: $0 [light|dark]"
  exit 1
fi

if pgrep -x nautilus >/dev/null 2>&1; then
  nautilus -q 2>/dev/null || true
fi

