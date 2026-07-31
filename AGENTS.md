# Agent Guidelines for imperative-dots

Welcome to the `imperative-dots` repository! This repository contains my dotfiles for setting up my Arch Linux machines, particularly focused on configuring the Hyprland Wayland compositor.

As an AI agent working in this repository, please adhere to the following guidelines:

## Overview

- **Project:** Arch Linux Dotfiles & Hyprland configuration (`imperative-dots`)
- **Primary OS:** Arch Linux
- **Window Manager / Compositor:** Hyprland
- **Installer Script:** `install.sh` handles the automated installation and configuration process.

## Key Directories & Files

- `install.sh`: The main installation script. When modifying this, ensure the script is robust, well-commented, and handles edge cases properly.
- `.config/`: Contains user-specific configuration files (e.g., Hyprland, terminals, bars, etc.).
- `scripts/`: Utility scripts used in the system.
- `README.md`: Basic instructions for installation and contact info.

## Guidelines for Modification

1. **Hyprland Configurations:** When updating Hyprland configurations in `.config/hypr/`, ensure compatibility with recent Hyprland releases and maintain the existing visual and structural style.
2. **Installation Script (`install.sh`):** 
   - Ensure the script remains safe to run (e.g., proper error handling, idempotency where possible).
   - If adding new packages, ensure they are available in the official Arch repositories or the AUR.
3. **Packages:** Do not introduce new packages without being explicitly asked.
4. **Documentation:** Keep the `README.md` clean. If new significant features are added, document them.
5. **Code Style:** Follow standard bash scripting practices for scripts (e.g., `install.sh` and files in `scripts/`). Use clear, descriptive variable names and comments.

## Key Skills

The following AI agent skills are installed in `.agents/skills/` to assist with Hyprland configuration and migration tasks:

1. **Hyprland Documentation Skill (`hyprland`)**
   - **Path:** [`.agents/skills/hyprland/SKILL.md`](file://.agents/skills/hyprland/SKILL.md)
   - **Source:** [marceloeatworld/hyprland-ai-skill](https://github.com/marceloeatworld/hyprland-ai-skill)
   - **Description:** Complete, auto-updated reference for the Hyprland Wayland compositor based on the official wiki. Covers Hyprland 0.55+ Lua configuration format (`hyprland.lua`), options, dispatchers, binds, window/layer rules, animations, and ecosystem tools (`hyprlock`, `hypridle`, `hyprpaper`, `hyprpicker`, `hyprsunset`, `xdg-desktop-portal-hyprland`).

2. **Hyprland Lua Migration Skill (`hyprland-lua-migration`)**
   - **Path:** [`.agents/skills/hyprland-lua-migration/SKILL.md`](file://.agents/skills/hyprland-lua-migration/SKILL.md)
   - **Source:** [dabstractor/hyprland-lua-migration](https://github.com/dabstractor/hyprland-lua-migration)
   - **Description:** Step-by-step migration guide and reference table for converting legacy Hyprland `hyprland.conf` (hyprlang syntax) to the modern v0.55 Lua API (`hl.*` functions).

### Updating Skills

To pull the latest updates for installed skills:
```bash
git -C .agents/skills/hyprland pull
git -C .agents/skills/hyprland-lua-migration pull
```
