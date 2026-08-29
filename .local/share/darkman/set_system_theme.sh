#!/bin/bash

THEME=$1

if [ "$THEME" == "light" ]; then
  # Change System Color Scheme
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'

  # Change GNOME Theme
  gsettings set org.gnome.desktop.interface gtk-theme 'Tahoe-Light'

  # 3. GTK4 / Libadwaita Styling
  mkdir -p "$HOME/.config/gtk-4.0"
  cp -a "$HOME/.themes/Tahoe-Light/gtk-4.0/"* "$HOME/.config/gtk-4.0/"

  sed -i 's/gtk-theme-name=.*/gtk-theme-name=Tahoe-Light/' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
  sed -i 's/gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=0/' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true

elif [ "$THEME" == "dark" ]; then
  # Change System Color Scheme
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

  # Change GNOME Theme
  gsettings set org.gnome.desktop.interface gtk-theme 'Tahoe-Dark'

  # 3. GTK4 / Libadwaita Styling
  mkdir -p "$HOME/.config/gtk-4.0"
  cp -a "$HOME/.themes/Tahoe-Dark/gtk-4.0/"* "$HOME/.config/gtk-4.0/"

  sed -i 's/gtk-theme-name=.*/gtk-theme-name=Tahoe-Dark/' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
  sed -i 's/gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=1/' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
else
  echo "Usage: $0 [light|dark]"
  exit 1
fi
