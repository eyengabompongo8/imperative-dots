import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: osdWindow
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "qs-osd"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            focusable: false
            color: "transparent"

            anchors {
                bottom: true
            }

            Scaler {
                id: scaler
                currentWidth: osdWindow.screen.width
                currentHeight: osdWindow.screen.height
            }

            property real baseScale: scaler.baseScale
            function s(val) {
                return scaler.s(val);
            }

            MatugenColors { id: mocha }

            // State management
            property bool isRevealed: false
            property string osdType: "volume" // "volume" | "mic" | "brightness" | "kbd" | "caps" | "num" | "camera" | "power"
            property real osdValue: 50.0
            property bool osdMuted: false
            property bool osdState: false
            property string osdText: "Volume"
            property string osdSubText: "50%"
            property string osdIcon: "󰕾"

            readonly property bool isToggleType: osdType === "caps" || osdType === "num" || osdType === "camera"
            readonly property bool isBadgeOnlyType: isToggleType || osdType === "power"

            readonly property color currentProfileColor: {
                if (osdType === "power") {
                    let p = osdSubText.toLowerCase();
                    if (p === "perform" || p === "performance") return mocha.red;
                    if (p === "saver" || p === "power-saver") return mocha.green;
                    return mocha.blue; // balance
                }
                return mocha.blue;
            }

            property real pillHeight: s(44)
            property real pillWidth: {
                if (osdType === "power") return s(230);
                if (isToggleType) return s(220);
                return s(300);
            }

            implicitWidth: pillWidth + s(36)
            implicitHeight: pillHeight + s(14)

            // Center window at the bottom of the screen
            margins {
                bottom: 0
                left: Math.max(0, (osdWindow.screen.width - implicitWidth) / 2)
                right: Math.max(0, (osdWindow.screen.width - implicitWidth) / 2)
            }

            Timer {
                id: autoHideTimer
                interval: 1800
                repeat: false
                onTriggered: osdWindow.isRevealed = false
            }

            function triggerShow() {
                osdWindow.isRevealed = true;
                autoHideTimer.restart();
            }

            function parseBool(val) {
                if (typeof val === "boolean") return val;
                if (typeof val === "number") return val > 0;
                if (typeof val === "string") {
                    let s = val.trim().toLowerCase();
                    return (s === "1" || s === "true" || s === "on" || s === "enabled");
                }
                return false;
            }

            function parseNum(val, def) {
                let n = parseFloat(val);
                return isNaN(n) ? (def || 0) : n;
            }

            // Core display setters
            function showVolumeInternal(val, muted) {
                let numVal = osdWindow.parseNum(val, 50);
                let isMuted = osdWindow.parseBool(muted);

                osdWindow.osdType = "volume";
                osdWindow.osdValue = Math.max(0, Math.min(150, numVal));
                osdWindow.osdMuted = isMuted;
                osdWindow.osdText = "Volume";
                osdWindow.osdSubText = isMuted ? "Muted" : Math.round(numVal) + "%";

                if (isMuted || numVal === 0) {
                    osdWindow.osdIcon = "󰝟";
                } else if (numVal < 33) {
                    osdWindow.osdIcon = "󰕿";
                } else if (numVal < 66) {
                    osdWindow.osdIcon = "󰖀";
                } else {
                    osdWindow.osdIcon = "󰕾";
                }

                osdWindow.triggerShow();
            }

            function showMicInternal(val, muted) {
                let numVal = osdWindow.parseNum(val, 100);
                let isMuted = osdWindow.parseBool(muted);

                osdWindow.osdType = "mic";
                osdWindow.osdValue = Math.max(0, Math.min(100, numVal));
                osdWindow.osdMuted = isMuted;
                osdWindow.osdText = "Microphone";
                osdWindow.osdSubText = isMuted ? "Muted" : Math.round(numVal) + "%";
                osdWindow.osdIcon = isMuted ? "󰍭" : "󰍬";

                osdWindow.triggerShow();
            }

            function showBrightnessInternal(val) {
                let numVal = osdWindow.parseNum(val, 50);

                osdWindow.osdType = "brightness";
                osdWindow.osdValue = Math.max(0, Math.min(100, numVal));
                osdWindow.osdMuted = false;
                osdWindow.osdText = "Brightness";
                osdWindow.osdSubText = Math.round(numVal) + "%";

                if (numVal < 33) {
                    osdWindow.osdIcon = "󰃞";
                } else if (numVal < 66) {
                    osdWindow.osdIcon = "󰃟";
                } else {
                    osdWindow.osdIcon = "󰃠";
                }

                osdWindow.triggerShow();
            }

            function showKbdInternal(val) {
                let numVal = osdWindow.parseNum(val, 0);

                osdWindow.osdType = "kbd";
                osdWindow.osdValue = Math.max(0, Math.min(100, numVal));
                osdWindow.osdMuted = false;
                osdWindow.osdText = "Keyboard";
                osdWindow.osdSubText = Math.round(numVal) + "%";
                osdWindow.osdIcon = "󰌌";

                osdWindow.triggerShow();
            }

            function showCapsInternal(state) {
                let isOn = osdWindow.parseBool(state);

                osdWindow.osdType = "caps";
                osdWindow.osdState = isOn;
                osdWindow.osdMuted = false;
                osdWindow.osdText = "Caps Lock";
                osdWindow.osdSubText = isOn ? "ON" : "OFF";
                osdWindow.osdIcon = "󰘲";

                osdWindow.triggerShow();
            }

            function showNumInternal(state) {
                let isOn = osdWindow.parseBool(state);

                osdWindow.osdType = "num";
                osdWindow.osdState = isOn;
                osdWindow.osdMuted = false;
                osdWindow.osdText = "Num Lock";
                osdWindow.osdSubText = isOn ? "ON" : "OFF";
                osdWindow.osdIcon = "󰎠";

                osdWindow.triggerShow();
            }

            function showCameraInternal(state) {
                let isOn = osdWindow.parseBool(state);

                osdWindow.osdType = "camera";
                osdWindow.osdState = isOn;
                osdWindow.osdMuted = !isOn;
                osdWindow.osdText = "Camera";
                osdWindow.osdSubText = isOn ? "ON" : "OFF";
                osdWindow.osdIcon = isOn ? "󰄀" : "󰄁";

                osdWindow.triggerShow();
            }

            function showProfileInternal(profile) {
                let p = (profile || "").trim().toLowerCase();
                osdWindow.osdType = "power";
                osdWindow.osdMuted = false;
                osdWindow.osdState = true;
                osdWindow.osdText = "Power Profile";

                if (p === "performance" || p === "perform") {
                    osdWindow.osdSubText = "Perform";
                    osdWindow.osdIcon = "󰓅";
                } else if (p === "balanced" || p === "balance") {
                    osdWindow.osdSubText = "Balance";
                    osdWindow.osdIcon = "󰗑";
                } else {
                    osdWindow.osdSubText = "Saver";
                    osdWindow.osdIcon = "󰌪";
                }

                osdWindow.triggerShow();
            }

            // Embedded persistent hardware watcher
            Process {
                id: hardwareWatcher
                running: true
                command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/osd_hardware_watcher.py"]
                stdout: SplitParser {
                    splitMarker: "\n"
                    onRead: data => {
                        let line = data.trim();
                        if (!line) return;
                        let parts = line.split("|");
                        if (parts.length < 2) return;
                        let type = parts[0];
                        let val = parts[1];
                        let extra = parts.length > 2 ? parts[2] : "";

                        if (type === "volume") osdWindow.showVolumeInternal(val, extra);
                        else if (type === "mic") osdWindow.showMicInternal(val, extra);
                        else if (type === "brightness") osdWindow.showBrightnessInternal(val);
                        else if (type === "kbd") osdWindow.showKbdInternal(val);
                        else if (type === "caps") osdWindow.showCapsInternal(val);
                        else if (type === "num") osdWindow.showNumInternal(val);
                        else if (type === "camera") osdWindow.showCameraInternal(val);
                        else if (type === "power") osdWindow.showProfileInternal(val);
                    }
                }
                onExited: {
                    hardwareRestartTimer.restart();
                }
            }

            Timer {
                id: hardwareRestartTimer
                interval: 500
                repeat: false
                onTriggered: hardwareWatcher.running = true
            }

            IpcHandler {
                target: "osd"

                function showVolume(val: string, muted: string): void {
                    osdWindow.showVolumeInternal(val, muted);
                }

                function showMic(val: string, muted: string): void {
                    osdWindow.showMicInternal(val, muted);
                }

                function showBrightness(val: string): void {
                    osdWindow.showBrightnessInternal(val);
                }

                function showKbdBacklight(val: string): void {
                    osdWindow.showKbdInternal(val);
                }

                function showCaps(state: string): void {
                    osdWindow.showCapsInternal(state);
                }

                function showNum(state: string): void {
                    osdWindow.showNumInternal(state);
                }

                function showCamera(state: string): void {
                    osdWindow.showCameraInternal(state);
                }

                function showProfile(profile: string): void {
                    osdWindow.showProfileInternal(profile);
                }

                function show(type: string, val: string, muted: string, text: string): void {
                    if (type === "volume") osdWindow.showVolumeInternal(val, muted);
                    else if (type === "mic") osdWindow.showMicInternal(val, muted);
                    else if (type === "brightness") osdWindow.showBrightnessInternal(val);
                    else if (type === "kbd") osdWindow.showKbdInternal(val);
                    else if (type === "caps") osdWindow.showCapsInternal(val);
                    else if (type === "num") osdWindow.showNumInternal(val);
                    else if (type === "camera") osdWindow.showCameraInternal(val);
                    else if (type === "power" || type === "profile") osdWindow.showProfileInternal(val);
                }
            }

            // OSD Pill Item
            Item {
                id: osdBox
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: osdWindow.pillWidth
                height: osdWindow.pillHeight

                Behavior on width {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                // Inverted Island Background (matching TopBar ears)
                BottomIslandBackground {
                    pillWidth: osdBox.width
                    pillHeight: osdBox.height
                    earRadius: osdWindow.s(14)
                    topRadius: osdWindow.s(14)
                    fillColor: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                    strokeColor: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
                    strokeWidth: 1.2

                    Behavior on fillColor { ColorAnimation { duration: 200 } }
                    Behavior on strokeColor { ColorAnimation { duration: 200 } }
                }

                // Slide up / down physics
                transform: Translate {
                    y: osdWindow.isRevealed ? 0 : (osdBox.height + osdWindow.s(20))
                    Behavior on y {
                        NumberAnimation {
                            duration: osdWindow.isRevealed ? 250 : 180
                            easing.type: osdWindow.isRevealed ? Easing.OutBack : Easing.InCubic
                            easing.overshoot: 1.05
                        }
                    }
                }

                opacity: osdWindow.isRevealed ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                // Content Layout
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: osdWindow.s(14)
                    anchors.rightMargin: osdWindow.s(14)
                    spacing: osdWindow.s(10)

                    // Leading Icon inside subtle rounded badge
                    Rectangle {
                        Layout.preferredWidth: osdWindow.s(28)
                        Layout.preferredHeight: osdWindow.s(28)
                        Layout.alignment: Qt.AlignVCenter
                        radius: osdWindow.s(14)
                        color: {
                            if (osdWindow.osdMuted) return Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.20);
                            if (osdWindow.osdType === "power") return Qt.rgba(osdWindow.currentProfileColor.r, osdWindow.currentProfileColor.g, osdWindow.currentProfileColor.b, 0.20);
                            if (osdWindow.isToggleType && !osdWindow.osdState) return Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.30);
                            return Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.20);
                        }

                        Text {
                            anchors.centerIn: parent
                            text: osdWindow.osdIcon
                            font.family: "SF Pro , Liga SFMono Nerd Font, Iosevka Nerd Font"
                            font.pixelSize: osdWindow.s(16)
                            color: {
                                if (osdWindow.osdMuted) return mocha.red;
                                if (osdWindow.osdType === "power") return osdWindow.currentProfileColor;
                                if (osdWindow.isToggleType && !osdWindow.osdState) return mocha.subtext0;
                                return mocha.blue;
                            }
                        }
                    }

                    // Center section (Label + Slider for Range types)
                    ColumnLayout {
                        visible: !osdWindow.isBadgeOnlyType
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: osdWindow.s(4)

                        // Top line: Label & Percentage
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: osdWindow.osdText
                                font.family: "SF Pro Text, SF Pro Display, sans-serif"
                                font.pixelSize: osdWindow.s(12)
                                font.weight: Font.DemiBold
                                color: mocha.text
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: osdWindow.osdSubText
                                font.family: "SF Pro Text, SF Pro Display, sans-serif"
                                font.pixelSize: osdWindow.s(12)
                                font.weight: Font.Black
                                color: osdWindow.osdMuted ? mocha.red : mocha.subtext0
                            }
                        }

                        // Bottom line: Slider bar (unified color)
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: osdWindow.s(6)

                            // Track
                            Rectangle {
                                anchors.fill: parent
                                radius: 99
                                color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.40)

                                // Fill (consistent mocha.blue across volume, brightness, kbd, mic; mocha.red when muted)
                                Rectangle {
                                    id: progressFill
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Math.min(parent.width, Math.max(0, parent.width * (osdWindow.osdValue / 100.0)))
                                    radius: 99
                                    color: osdWindow.osdMuted ? mocha.red : mocha.blue

                                    Behavior on width {
                                        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                                    }
                                }
                            }
                        }
                    }

                    // Badge-Only Row Layout (For Caps Lock, Num Lock, Camera, Power Profile)
                    RowLayout {
                        visible: osdWindow.isBadgeOnlyType
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: osdWindow.osdText
                            font.family: "SF Pro Text, SF Pro Display, sans-serif"
                            font.pixelSize: osdWindow.s(13)
                            font.weight: Font.DemiBold
                            color: mocha.text
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        // State pill badge (matching BatteryPopup power profile colors)
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: badgeText.implicitWidth + osdWindow.s(18)
                            implicitHeight: osdWindow.s(22)
                            radius: 99
                            color: {
                                if (osdWindow.osdType === "power") return osdWindow.currentProfileColor;
                                if (osdWindow.osdState) return mocha.blue;
                                return Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.40);
                            }

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: osdWindow.osdSubText
                                font.family: "SF Pro Text, SF Pro Display, sans-serif"
                                font.pixelSize: osdWindow.s(11)
                                font.weight: Font.Black
                                color: (osdWindow.osdType === "power" || osdWindow.osdState) ? mocha.crust : mocha.subtext0
                            }

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }
                }
            }
        }
    }
}
