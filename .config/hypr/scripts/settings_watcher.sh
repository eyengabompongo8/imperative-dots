#!/usr/bin/env bash

# File paths
SETTINGS_FILE="$HOME/.config/hypr/settings.json"
WEATHER_SCRIPT="$HOME/.config/hypr/scripts/weather.sh"
ENV_FILE="$HOME/.config/hypr/scripts/quickshell/calendar/.env"

# Target configuration files
CONF_DIR="$HOME/.config/hypr/config"
TMPL_DIR="$HOME/.config/hypr/templates"
SETTINGS_CONF="$CONF_DIR/settings.lua"
AUTOSTART_CONF="$CONF_DIR/autostart.lua"
ENV_CONF="$CONF_DIR/env.lua"
KEYBINDS_CONF="$CONF_DIR/keybindings.lua"
MONITORS_CONF="$CONF_DIR/monitors.lua"
ZSH_RC="$HOME/.zshrc"

# Ensure the required files and directories exist
mkdir -p "$CONF_DIR" "$TMPL_DIR" "$(dirname "$SETTINGS_FILE")" "$(dirname "$ENV_FILE")"
[ ! -f "$SETTINGS_FILE" ] && echo "{}" > "$SETTINGS_FILE"

CACHE_DIR="$HOME/.cache/settings_watcher"
mkdir -p "$CACHE_DIR"

compile_settings() {
    echo "Regenerating configurations from templates..."

    # Hash existing configs before any changes, split by monitor vs non-monitor.
    # This means a pure uiScale/wallpaperDir/weatherApiKey write never triggers a reload.
    OLD_NONMON_HASH=$(md5sum "$SETTINGS_CONF" "$KEYBINDS_CONF" "$AUTOSTART_CONF" "$ENV_CONF" 2>/dev/null | md5sum)
    OLD_MON_HASH=$(md5sum "$MONITORS_CONF" 2>/dev/null | md5sum)

    # Read state from JSON (Using 'has' to safely parse booleans)
    LANG=$(jq -r '.language // "us"' "$SETTINGS_FILE")
    KB_OPT=$(jq -r '.kbOptions // "grp:alt_shift_toggle"' "$SETTINGS_FILE")
    WP_DIR=$(jq -r '.wallpaperDir // empty' "$SETTINGS_FILE")

    # Safely parse booleans so "false" doesn't trigger a fallback
    GUIDE_STARTUP=$(jq -r 'if has("openGuideAtStartup") then .openGuideAtStartup else true end' "$SETTINGS_FILE")

    PIC_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
    VID_DIR="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")"

    # Read the hardware variables injected by install.sh directly out of the JSON
    HW_ENV=$(jq -r '.hardwareEnvs[]? // empty' "$SETTINGS_FILE")

    # 1. Regenerate env.lua using the template
    echo "Regenerating env.lua..."
    sed -e "s|{{XDG_PICTURES_DIR}}|$PIC_DIR|g" \
        -e "s|{{XDG_VIDEOS_DIR}}|$VID_DIR|g" \
        -e "s|{{WALLPAPER_DIR}}|$WP_DIR|g" \
        -e "s|{{SCRIPT_DIR}}|$HOME/.config/hypr/scripts|g" \
        "$TMPL_DIR/env.lua.template" > "${ENV_CONF}.tmp"

    HW_ENV=$(jq -r '.hardwareEnvs[]? | "hl.env(\"\(. | split(",")[0])\", \"\(. | split(",")[1])\")" // empty' "$SETTINGS_FILE")
    # Use awk to safely substitute the multi-line HW_ENV array without breaking escapes
    awk -v hw="$HW_ENV" '{
        if (index($0, "{{HARDWARE_ENV}}")) {
            print hw
        } else {
            print $0
        }
    }' "${ENV_CONF}.tmp" > "$ENV_CONF"
    rm -f "${ENV_CONF}.tmp"

    # Sync ZSH_RC if Wallpaper Dir changed
    if [ -n "$WP_DIR" ] && [ -f "$ZSH_RC" ]; then
        sed -i "s|^export WALLPAPER_DIR=.*|export WALLPAPER_DIR=\"$WP_DIR\"|" "$ZSH_RC"
    fi

    # 2. Regenerate settings.lua using template
    echo "Regenerating settings.lua..."
    sed -e "s|{{KB_LAYOUT}}|$LANG|g" \
        -e "s|{{KB_OPTIONS}}|$KB_OPT|g" \
        "$TMPL_DIR/settings.lua.template" > "$SETTINGS_CONF"

    # 3. Regenerate autostart.lua
    echo "Regenerating autostart.lua..."
    cp "$TMPL_DIR/autostart.lua.template" "$AUTOSTART_CONF"

    jq -r '.startup[]? | "    hl.exec_cmd(" + (.command | tojson) + ")"' "$SETTINGS_FILE" >> "$AUTOSTART_CONF"

    # Evaluate the guide boolean natively in jq and output the line ONLY if it resolves to true
    if [[ $(jq -r 'if (if type == "object" and has("openGuideAtStartup") then .openGuideAtStartup else true end) then "yes" else "no" end' "$SETTINGS_FILE") == "yes" ]]; then
        echo "    hl.exec_cmd(\"bash -c 'sleep 1 && ~/.config/hypr/scripts/qs_manager.sh toggle guide'\")" >> "$AUTOSTART_CONF"
    fi
    echo "end)" >> "$AUTOSTART_CONF"

    # 4. Regenerate keybindings.lua
    echo "Regenerating keybindings.lua..."
    cp "$TMPL_DIR/keybinds.lua.template" "$KEYBINDS_CONF"
    jq -r '.keybinds[]? | "hl.bind(\"\(if (.mods // "") != "" and (.mods | gsub("^\\s+|\\s+$"; "")) != "" then (((.mods | gsub("\\$mainMod"; "SUPER") | gsub("^\\s+|\\s+$"; "") | gsub("\\s+"; " + ")) + " + ")) else "" end)\(.key // "")\", \(if .dispatcher == "lua" then "function() " + .command + " end" elif .dispatcher == "exec" then "hl.dsp.exec_cmd(" + (.command | tojson) + ")" elif .dispatcher == "workspace" then "hl.dsp.focus({ workspace = " + (.command | tojson) + " })" elif .dispatcher == "movetoworkspace" then "hl.dsp.window.move({ workspace = " + (.command | tojson) + " })" elif .dispatcher == "movefocus" then "hl.dsp.focus({ direction = " + (.command | tojson) + " })" elif .dispatcher == "movewindow" then "hl.dsp.window.move({ direction = " + (.command | tojson) + " })" elif .dispatcher == "resizeactive" then "hl.dsp.window.resize({ x = " + (.command | split(" ")[0]) + ", y = " + (.command | split(" ")[1]) + ", relative = true })" elif .dispatcher == "killactive" then "hl.dsp.window.close()" elif .dispatcher == "togglefloating" then "hl.dsp.window.float({ action = \"toggle\" })" elif .dispatcher == "togglesplit" then "hl.dsp.layout(\"togglesplit\")" elif .dispatcher == "fullscreen" then (if .command == "1" or .command == "maximized" then "hl.dsp.window.fullscreen({ mode = \"maximized\" })" else "hl.dsp.window.fullscreen()" end) else "hl.dsp." + .dispatcher + "(" + (.command | tojson) + ")" end)\(if .type == "binde" then ", { repeating = true }" elif .type == "bindl" then ", { locked = true }" elif .type == "bindel" then ", { repeating = true, locked = true }" else "" end))"' "$SETTINGS_FILE" >> "$KEYBINDS_CONF"

    # 5. Regenerate monitors.lua
    echo "Regenerating monitors.lua..."
    cp "$TMPL_DIR/monitors.lua.template" "$MONITORS_CONF"
    MONITOR_COUNT=$(jq '.monitors | length' "$SETTINGS_FILE" 2>/dev/null)
    if [[ "$MONITOR_COUNT" -gt 0 ]]; then
        jq -r '.monitors[]? | if .disabled then "hl.monitor({ output = \"\(.name)\", mode = \"disable\" })" elif (.mirrorOf // "") != "" then "hl.monitor({ output = \"\(.name)\", mode = \"preferred\", position = \"auto\", scale = \(.scale), mirror = \"\(.mirrorOf)\" })" else "hl.monitor({ output = \"\(.name)\", mode = \"\(.resW)x\(.resH)@\(.rate)\", position = \"\(.x)x\(.y)\", scale = \(.scale)\(if .transform and .transform != 0 then ", transform = \(.transform)" else "" end) })" end' "$SETTINGS_FILE" >> "$MONITORS_CONF"
    else
        echo 'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })' >> "$MONITORS_CONF"
    fi

    # Hash after changes
    NEW_NONMON_HASH=$(md5sum "$SETTINGS_CONF" "$KEYBINDS_CONF" "$AUTOSTART_CONF" "$ENV_CONF" 2>/dev/null | md5sum)
    NEW_MON_HASH=$(md5sum "$MONITORS_CONF" 2>/dev/null | md5sum)

    if [ "$OLD_MON_HASH" != "$NEW_MON_HASH" ]; then
        # Monitor layout actually changed — full reload needed
        echo "Monitor config changed, reloading Hyprland..."
        hyprctl reload
    elif [ "$OLD_NONMON_HASH" != "$NEW_NONMON_HASH" ]; then
        # Non-monitor settings changed (keybinds, autostart, input, env) — reload safe, no display flicker
        echo "Non-monitor config changed, reloading Hyprland..."
        hyprctl reload
    else
        # Nothing that affects Hyprland changed (e.g. uiScale, weatherApiKey) — skip reload entirely
        echo "No Hyprland config changes detected, skipping reload."
    fi
}

# If called with --compile, execute once and exit (used by install.sh)
if [[ "$1" == "--compile" ]]; then
    compile_settings
    exit 0
fi

echo "Started watching settings directories for changes..."

inotifywait -m -q -e close_write,moved_to --format '%w%f' "$(dirname "$SETTINGS_FILE")" "$(dirname "$ENV_FILE")" | while read -r filepath; do

    # ---------------------------------------------------------
    # SETTINGS JSON TRIGGER
    # ---------------------------------------------------------
    if [[ "$filepath" == "$SETTINGS_FILE" ]]; then
        compile_settings
    fi

    # ---------------------------------------------------------
    # .ENV WEATHER TRIGGER
    # ---------------------------------------------------------
    if [[ "$filepath" == "$ENV_FILE" ]]; then
        echo ".env updated! Forcing weather cache refresh..."
        if [ -x "$WEATHER_SCRIPT" ]; then
            "$WEATHER_SCRIPT" --getdata &
        else
            bash "$WEATHER_SCRIPT" --getdata &
        fi
    fi
done
