#!/usr/bin/env bash

# QuickShell OSD Controller
SHELL_PATH="$HOME/.config/hypr/scripts/quickshell/Shell.qml"
TARGET=$1
ACTION=$2
STEP="${3:-5}"

send_ipc() {
    quickshell -p "$SHELL_PATH" ipc call osd "$@" >/dev/null 2>&1
}

case "$TARGET" in
    volume)
        case "$ACTION" in
            raise)
                wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ "${STEP}%+"
                ;;
            lower)
                wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP}%-"
                ;;
            mute-toggle)
                wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
                ;;
            check)
                ;;
        esac

        VOL=$(pamixer --get-volume 2>/dev/null || echo "50")
        MUTE=$(pamixer --get-mute 2>/dev/null || echo "false")
        send_ipc showVolume "$VOL" "$MUTE"
        ;;

    mic)
        case "$ACTION" in
            raise)
                wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SOURCE@ "${STEP}%+"
                ;;
            lower)
                wpctl set-volume @DEFAULT_AUDIO_SOURCE@ "${STEP}%-"
                ;;
            mute-toggle)
                wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
                ;;
            check)
                ;;
        esac

        VOL=$(pamixer --default-source --get-volume 2>/dev/null || echo "100")
        MUTE=$(pamixer --default-source --get-mute 2>/dev/null || echo "false")
        send_ipc showMic "$VOL" "$MUTE"
        ;;

    brightness)
        case "$ACTION" in
            raise)
                brightnessctl set "${STEP}%+" >/dev/null 2>&1
                ;;
            lower)
                brightnessctl set "${STEP}%-" >/dev/null 2>&1
                ;;
            check)
                ;;
        esac

        BRI=$(brightnessctl -m 2>/dev/null | grep -E "backlight" | awk -F, '{print substr($4, 1, length($4)-1)}' | head -n1)
        [[ -z "$BRI" ]] && BRI=$(brightnessctl -m 2>/dev/null | awk -F, '{print substr($4, 1, length($4)-1)}' | head -n1)
        [[ -z "$BRI" ]] && BRI=50
        send_ipc showBrightness "$BRI"
        ;;

    kbd)
        # Samsung Galaxy Book 4: the Fn+F9 keyboard backlight key is handled ENTIRELY
        # by the samsung-galaxybook kernel driver. The driver directly writes to:
        #   /sys/class/leds/samsung-galaxybook::kbd_backlight/brightness
        # and then sets POLLPRI on brightness_hw_changed.
        #
        # The osd_hardware_watcher.py detects this via select(POLLPRI) on
        # brightness_hw_changed and emits the OSD event automatically — no
        # keybind or osd.sh call is needed for the physical Fn+F9 key.
        #
        # ⚠ Do NOT add a Hyprland keybind for XF86KbdBrightnessUp/Down that
        #    calls "osd.sh kbd raise/lower" — KEYBOARD_KEY_ac=unknown in the hwdb
        #    means the key is passed to userspace but Hyprland would ALSO call
        #    brightnessctl, causing a double-step on top of what the driver did.
        #
        # This handler is kept for MANUAL control only (raise/lower/toggle/check
        # invoked explicitly, e.g. from other scripts or keybinds not triggered
        # by Fn+F9 itself).
        KBD_DEV=$(brightnessctl --list 2>/dev/null | grep -i "kbd_backlight" | awk -F"'" '{print $2}' | head -n1)
        [[ -z "$KBD_DEV" ]] && KBD_DEV=$(brightnessctl --list 2>/dev/null | grep -i "kbd" | awk -F"'" '{print $2}' | head -n1)

        if [[ -n "$KBD_DEV" ]]; then
            case "$ACTION" in
                raise)
                    brightnessctl -d "$KBD_DEV" set 1+ >/dev/null 2>&1
                    ;;
                lower)
                    brightnessctl -d "$KBD_DEV" set 1- >/dev/null 2>&1
                    ;;
                toggle)
                    CURR=$(brightnessctl -d "$KBD_DEV" g 2>/dev/null || echo 0)
                    MAX=$(brightnessctl -d "$KBD_DEV" m 2>/dev/null || echo 1)
                    if [[ "$CURR" -gt 0 ]]; then
                        brightnessctl -d "$KBD_DEV" set 0 >/dev/null 2>&1
                    else
                        brightnessctl -d "$KBD_DEV" set "$MAX" >/dev/null 2>&1
                    fi
                    ;;
                check)
                    ;;
            esac

            CURR=$(brightnessctl -d "$KBD_DEV" g 2>/dev/null || echo 0)
            MAX=$(brightnessctl -d "$KBD_DEV" m 2>/dev/null || echo 1)
            [[ "$MAX" -le 0 ]] && MAX=1
            PCT=$(( CURR * 100 / MAX ))
            send_ipc showKbdBacklight "$PCT"
        fi
        ;;

    caps)
        sleep 0.08
        STATE="0"
        CAPS_LED=$(brightnessctl -d '*capslock*' g 2>/dev/null)
        if [[ "$CAPS_LED" == "1" ]]; then
            STATE="1"
        elif [[ "$CAPS_LED" == "0" ]]; then
            STATE="0"
        else
            HYPR_CAPS=$(hyprctl devices -j 2>/dev/null | jq '[.keyboards[].capsLock] | any' 2>/dev/null)
            [[ "$HYPR_CAPS" == "true" ]] && STATE="1" || STATE="0"
        fi
        send_ipc showCaps "$STATE"
        ;;

    num)
        sleep 0.08
        STATE="0"
        NUM_LED=$(brightnessctl -d '*numlock*' g 2>/dev/null)
        if [[ "$NUM_LED" == "1" ]]; then
            STATE="1"
        elif [[ "$NUM_LED" == "0" ]]; then
            STATE="0"
        else
            HYPR_NUM=$(hyprctl devices -j 2>/dev/null | jq '[.keyboards[].numLock] | any' 2>/dev/null)
            [[ "$HYPR_NUM" == "true" ]] && STATE="1" || STATE="0"
        fi
        send_ipc showNum "$STATE"
        ;;

    camera)
        CAM_STATE_FILE="/tmp/osd_cam_state"
        CURR="1"
        [[ -f "$CAM_STATE_FILE" ]] && CURR=$(cat "$CAM_STATE_FILE")

        case "$ACTION" in
            toggle)
                [[ "$CURR" == "1" ]] && CURR="0" || CURR="1"
                ;;
            on)
                CURR="1"
                ;;
            off)
                CURR="0"
                ;;
            check)
                ;;
        esac

        echo "$CURR" > "$CAM_STATE_FILE"
        send_ipc showCamera "$CURR"
        ;;

    power|profile)
        case "$ACTION" in
            cycle)
                CURR=$(powerprofilesctl get 2>/dev/null || echo "power-saver")
                case "$CURR" in
                    power-saver|low-power)
                        NEXT="balanced"
                        ;;
                    balanced)
                        NEXT="performance"
                        ;;
                    performance)
                        NEXT="power-saver"
                        ;;
                    *)
                        NEXT="balanced"
                        ;;
                esac
                powerprofilesctl set "$NEXT" 2>/dev/null
                ;;
            performance|perform)
                powerprofilesctl set "performance" 2>/dev/null
                ;;
            balanced|balance)
                powerprofilesctl set "balanced" 2>/dev/null
                ;;
            power-saver|saver)
                powerprofilesctl set "power-saver" 2>/dev/null
                ;;
            check)
                ;;
        esac

        PROFILE=$(powerprofilesctl get 2>/dev/null || cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo "balanced")
        send_ipc showProfile "$PROFILE"
        ;;

    *)
        echo "Usage: $0 {volume|mic|brightness|kbd|caps|num|camera|power} {raise|lower|mute-toggle|toggle|cycle|check} [step]"
        ;;
esac
