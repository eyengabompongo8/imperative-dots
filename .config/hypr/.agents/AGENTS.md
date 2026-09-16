# Agent Guidelines for ~/.config/hypr

This is the live Hyprland configuration managed by
[`imperative-dots`](https://github.com/eyenga/dotfiles).

## Available Skills

The following AI skills are installed in `.agents/skills/` by the `install.sh`
installer. Antigravity discovers them automatically when working in this directory.

1. **`hyprland`** — Complete Hyprland Wayland compositor reference (v0.55+ Lua
   API, options, dispatchers, binds, window/layer rules, animations, and
   ecosystem tools: `hyprlock`, `hypridle`, `hyprpaper`, `hyprpicker`,
   `hyprsunset`, `xdg-desktop-portal-hyprland`).

2. **`hyprland-lua-migration`** — Step-by-step guide for migrating legacy
   `hyprland.conf` (hyprlang syntax) to the modern Lua API (`hl.*` functions).

## Updating Skills

To pull the latest version of each skill:

```bash
git -C ~/.config/hypr/.agents/skills/hyprland pull
git -C ~/.config/hypr/.agents/skills/hyprland-lua-migration pull
```

Or simply re-run the dotfiles installer — it handles updates automatically.
