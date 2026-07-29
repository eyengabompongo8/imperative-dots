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

