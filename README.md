> [!WARNING]
> This installer sends anonymous non-identifying telemetry that helps me debug problems and track the amount of users 

### To install:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eyengabompongo8/imperative-dots/mine/install.sh)"
```

### Reach out to me:
#### twitter/x: @ilyamirox
#### reddit: u/ilyamiro1
#### telegram: @sacrificeit
#### email: ilyamiro.work@gmail.com

## ⚙️ Configuration Architecture

This dotfiles project uses a highly dynamic, template-driven configuration system for Hyprland to support live updates via the UI (Quickshell).

### 1. Single Source of Truth
The primary source of truth for dynamic settings (keybinds, monitors, autostart, etc.) is `~/.config/hypr/settings.json`. The repository provides the base defaults in `.config/hypr/default_settings.json`.

### 2. The Template System
Hyprland's configuration is modularized into `~/.config/hypr/config/*.lua`. 
However, **you should not edit these files directly**. They are automatically generated from `.lua.template` files located in `~/.config/hypr/templates/`.

### 3. Settings Watcher (`settings_watcher.sh`)
The script `~/.config/hypr/scripts/settings_watcher.sh` runs in the background and uses `inotifywait` to monitor `settings.json`. When a change is detected:
- It uses `jq` to parse the JSON.
- It uses `sed`/`awk` to inject values (like keyboard layouts, monitor resolutions, and dynamic keybinds) into the `*.lua.template` files.
- It outputs the final `.lua` configuration files into `~/.config/hypr/config/`.
- It intelligently reloads Hyprland only if a reload is required.

### 4. Dynamic Colors (Matugen)
System colors are dynamically generated from wallpapers using **Matugen**. 
Matugen relies on `.config/matugen/templates/hyprland.lua.template` and outputs the system color palette to `~/.config/hypr/colors.lua`. The script `matugen_reload.sh` manages this workflow.

### 5. Hardware Injections (`install.sh`)
The `install.sh` script detects your hardware (e.g., NVIDIA GPUs) during setup and permanently bakes hardware-specific environment variables directly into the `env.lua.template` so they persist through all future configuration regenerations.
