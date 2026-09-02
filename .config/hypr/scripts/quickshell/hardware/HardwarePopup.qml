import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    focus: true

    Caching { id: paths }

    // --- RECEIVE FROM MAIN.QML (Required by widgetStack) ---
    property var notifModel
    property var liveNotifs
    property real layoutWidth: 0
    property real layoutHeight: 0

    // --- Responsive Scaling Logic ---
    Scaler {
        id: scaler
        currentWidth: Screen.width
    }

    function s(val) {
        return scaler.s(val);
    }

    readonly property real targetMasterHeight: {
        let count = (hasBatteryThreshold ? 1 : 0) + (hasTurbo ? 1 : 0);
        if (count >= 2) return s(275);
        if (count === 1) return s(205);
        return s(155);
    }

    // -------------------------------------------------------------------------
    // COLORS (Dynamic Matugen Palette)
    // -------------------------------------------------------------------------
    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0
    readonly property color overlay1: _theme.overlay1
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2

    readonly property color mauve: _theme.mauve
    readonly property color pink: _theme.pink
    readonly property color red: _theme.red
    readonly property color maroon: _theme.maroon
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow
    readonly property color green: _theme.green
    readonly property color teal: _theme.teal
    readonly property color sapphire: _theme.sapphire
    readonly property color blue: _theme.blue

    // -------------------------------------------------------------------------
    // STATE & CONFIG
    // -------------------------------------------------------------------------
    readonly property string ctlScript: "~/.config/hypr/scripts/quickshell/hardware/hw_ctl.sh"

    property bool hasBatteryThreshold: false
    property int currentBatteryThreshold: 100
    property int selectedBatteryThreshold: 100

    property bool hasTurbo: false
    property bool currentTurboEnabled: false
    property bool selectedTurboEnabled: false

    property bool userModifiedBat: false
    property bool userModifiedTurbo: false

    property string userPassword: ""
    property bool showPassword: false
    property bool isApplying: false
    property string statusMessage: ""
    property bool isStatusSuccess: false
    property bool showStatus: false

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
    }

    // -------------------------------------------------------------------------
    // DATA FETCHING & LIVE SYNC
    // -------------------------------------------------------------------------
    function refresh() {
        if (!window.isApplying) {
            hwFetcher.running = false;
            hwFetcher.running = true;
        }
    }

    onVisibleChanged: {
        if (visible) {
            window.userModifiedBat = false;
            window.userModifiedTurbo = false;
            refresh();
        } else {
            window.userModifiedBat = false;
            window.userModifiedTurbo = false;
            passInput.text = "";
            window.userPassword = "";
            window.showStatus = false;
        }
    }

    StackView.onStatusChanged: {
        if (StackView.status === StackView.Active) {
            refresh();
        }
    }

    // Live poller while window is open
    Timer {
        id: livePoller
        interval: 3000
        repeat: true
        running: window.visible
        onTriggered: window.refresh()
    }

    Process {
        id: hwFetcher
        command: ["bash", "-c", ctlScript + " get 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let txt = this.text ? this.text.trim() : "";
                    if (!txt || txt.charAt(0) !== '{') return;
                    let d = JSON.parse(txt);
                    window.hasBatteryThreshold = !!d.hasBatteryThreshold;
                    if (d.batteryThreshold !== undefined) {
                        let bt = parseInt(d.batteryThreshold);
                        if (bt >= 50 && bt <= 100) {
                            window.currentBatteryThreshold = bt;
                            // Only overwrite input if the user has not staged a change
                            if (!window.userModifiedBat && !batteryInput.activeFocus && !window.isApplying) {
                                window.selectedBatteryThreshold = bt;
                                batteryInput.text = bt.toString();
                            }
                        }
                    }
                    window.hasTurbo = !!d.hasTurbo;
                    if (d.turbo !== undefined) {
                        let t = (d.turbo === "on");
                        window.currentTurboEnabled = t;
                        // Only overwrite toggle if user has not staged a change
                        if (!window.userModifiedTurbo && !window.isApplying) {
                            window.selectedTurboEnabled = t;
                        }
                    }
                } catch(e) {
                    console.log("Error parsing hw_ctl get output:", e);
                }
            }
        }
    }

    property var nextActionCallback: null

    Process {
        id: batSetter
        property string targetVal: ""
        command: ["bash", "-c", "echo '" + window.userPassword.replace(/'/g, "'\\''") + "' | " + ctlScript + " set-battery " + targetVal]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let txt = this.text ? this.text.trim() : "";
                    if (!txt || txt.charAt(0) !== '{') return;
                    let res = JSON.parse(txt);
                    if (res.success) {
                        window.currentBatteryThreshold = parseInt(batSetter.targetVal);
                        if (window.nextActionCallback) {
                            let cb = window.nextActionCallback;
                            window.nextActionCallback = null;
                            cb();
                        } else {
                            window.isApplying = false;
                            window.userModifiedBat = false;
                            window.userModifiedTurbo = false;
                            passInput.text = "";
                            window.userPassword = "";
                            triggerStatus("Saved!", true);
                            window.refresh();
                        }
                    } else {
                        window.isApplying = false;
                        window.nextActionCallback = null;
                        triggerStatus(res.error || "Failed: incorrect password", false);
                    }
                } catch(e) {
                    window.isApplying = false;
                    window.nextActionCallback = null;
                    triggerStatus("Execution error", false);
                }
            }
        }
    }

    Process {
        id: turboSetter
        property string targetVal: ""
        command: ["bash", "-c", "echo '" + window.userPassword.replace(/'/g, "'\\''") + "' | " + ctlScript + " set-turbo " + targetVal]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let txt = this.text ? this.text.trim() : "";
                    if (!txt || txt.charAt(0) !== '{') return;
                    let res = JSON.parse(txt);
                    if (res.success) {
                        window.currentTurboEnabled = (turboSetter.targetVal === "on");
                        if (window.nextActionCallback) {
                            let cb = window.nextActionCallback;
                            window.nextActionCallback = null;
                            cb();
                        } else {
                            window.isApplying = false;
                            window.userModifiedBat = false;
                            window.userModifiedTurbo = false;
                            passInput.text = "";
                            window.userPassword = "";
                            triggerStatus("Saved!", true);
                            window.refresh();
                        }
                    } else {
                        window.isApplying = false;
                        window.nextActionCallback = null;
                        triggerStatus(res.error || "Failed: incorrect password", false);
                    }
                } catch(e) {
                    window.isApplying = false;
                    window.nextActionCallback = null;
                    triggerStatus("Execution error", false);
                }
            }
        }
    }

    function applyChanges() {
        if (isApplying) return;

        let hasPendingBat = window.hasBatteryThreshold && (window.selectedBatteryThreshold !== window.currentBatteryThreshold);
        let hasPendingTurbo = window.hasTurbo && (window.selectedTurboEnabled !== window.currentTurboEnabled);

        if (!hasPendingBat && !hasPendingTurbo) {
            triggerStatus("No changes to apply", false);
            return;
        }

        window.isApplying = true;
        window.showStatus = false;

        if (hasPendingBat && hasPendingTurbo) {
            turboSetter.targetVal = window.selectedTurboEnabled ? "on" : "off";
            window.nextActionCallback = function() {
                batSetter.targetVal = window.selectedBatteryThreshold.toString();
                batSetter.running = false;
                batSetter.running = true;
            };
            turboSetter.running = false;
            turboSetter.running = true;
        } else if (hasPendingTurbo) {
            window.nextActionCallback = null;
            turboSetter.targetVal = window.selectedTurboEnabled ? "on" : "off";
            turboSetter.running = false;
            turboSetter.running = true;
        } else if (hasPendingBat) {
            window.nextActionCallback = null;
            batSetter.targetVal = window.selectedBatteryThreshold.toString();
            batSetter.running = false;
            batSetter.running = true;
        }
    }

    function triggerStatus(msg, isSuccess) {
        window.statusMessage = msg;
        window.isStatusSuccess = isSuccess;
        window.showStatus = true;
        statusTimer.restart();
    }

    Timer {
        id: statusTimer
        interval: 3500
        repeat: false
        onTriggered: window.showStatus = false
    }

    // -------------------------------------------------------------------------
    // ANIMATIONS
    // -------------------------------------------------------------------------
    property real introMain: 0
    property real introHeader: 0
    property real introContent: 0

    ParallelAnimation {
        running: true
        NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: 500; easing.type: Easing.OutExpo }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: window; property: "introHeader"; from: 0; to: 1.0; duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            NumberAnimation { target: window; property: "introContent"; from: 0; to: 1.0; duration: 500; easing.type: Easing.OutExpo }
        }
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.96 + (0.04 * introMain)
        opacity: introMain
        transform: Translate { y: window.s(14) * (1 - introMain) }

        Rectangle {
            anchors.fill: parent
            radius: window.s(20)
            color: "transparent"
            border.width: 0
            clip: true

            // Rotating Background Ambient Blobs
            Rectangle {
                width: parent.width * 0.85; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * window.s(80)
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * window.s(60)
                opacity: 0.05
                color: window.mauve
            }
            Rectangle {
                width: parent.width * 0.9; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * window.s(-80)
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * window.s(-60)
                opacity: 0.04
                color: window.mauve
            }

            ColumnLayout {
                id: mainLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: window.s(16)
                spacing: window.s(10)

                // =============================================================
                // HEADER
                // =============================================================
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(38)
                    opacity: window.introHeader
                    transform: Translate { y: window.s(15) * (1.0 - window.introHeader) }

                    RowLayout {
                        anchors.fill: parent
                        spacing: window.s(10)

                        Rectangle {
                            width: window.s(36); height: window.s(36)
                            radius: window.s(10)
                            color: Qt.rgba(window.mauve.r, window.mauve.g, window.mauve.b, 0.15)
                            border.color: Qt.rgba(window.mauve.r, window.mauve.g, window.mauve.b, 0.3)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "" // Outline Crossed Tools (\uEB6D)
                                font.family: "SF Pro "
                                font.pixelSize: window.s(18)
                                color: window.mauve
                            }
                        }

                        Text {
                            text: "Hardware Settings"
                            font.family: "SF Pro Display"
                            font.pixelSize: window.s(16)
                            font.weight: Font.Bold
                            color: window.text
                        }

                        Item { Layout.fillWidth: true }

                        // Status notification tag in header (Properly sized without overflow)
                        Rectangle {
                            visible: window.showStatus
                            Layout.preferredHeight: window.s(24)
                            Layout.preferredWidth: statusRow.implicitWidth + window.s(16)
                            radius: window.s(6)
                            color: window.isStatusSuccess ? Qt.rgba(window.green.r, window.green.g, window.green.b, 0.18) : Qt.rgba(window.red.r, window.red.g, window.red.b, 0.18)
                            border.color: window.isStatusSuccess ? window.green : window.red
                            border.width: 1

                            RowLayout {
                                id: statusRow
                                anchors.centerIn: parent
                                spacing: window.s(5)

                                Text {
                                    text: window.isStatusSuccess ? "✓" : "✗"
                                    font.family: "SF Pro Text"
                                    font.pixelSize: window.s(11)
                                    font.weight: Font.Black
                                    color: window.isStatusSuccess ? window.green : window.red
                                }

                                Text {
                                    id: headerStatusText
                                    text: window.statusMessage
                                    font.family: "SF Pro Text"
                                    font.pixelSize: window.s(11)
                                    font.weight: Font.Bold
                                    color: window.isStatusSuccess ? window.green : window.red
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: window.surface0
                }

                // =============================================================
                // CONTENT
                // =============================================================
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: window.s(10)
                    opacity: window.introContent

                    // ---------------------------------------------------------
                    // 1. BATTERY CHARGING THRESHOLD SECTION
                    // ---------------------------------------------------------
                    Rectangle {
                        visible: window.hasBatteryThreshold
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(56)
                        radius: window.s(12)
                        color: Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.5)
                        border.color: window.surface1
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: window.s(12)
                            anchors.rightMargin: window.s(12)
                            spacing: window.s(10)

                            Text {
                                text: "󰂄"
                                font.family: "SF Pro "
                                font.pixelSize: window.s(18)
                                color: window.mauve
                            }

                            ColumnLayout {
                                spacing: 1

                                Text {
                                    text: "Battery Charging Limit"
                                    font.family: "SF Pro Text"
                                    font.pixelSize: window.s(13)
                                    font.weight: Font.Bold
                                    color: window.text
                                }

                                Text {
                                    text: "Current: " + window.currentBatteryThreshold + "%"
                                    font.family: "SF Pro Text"
                                    font.pixelSize: window.s(11)
                                    color: window.mauve
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Minus Stepper Button
                            Rectangle {
                                width: window.s(28); height: window.s(28)
                                radius: window.s(6)
                                color: minusMouse.containsMouse ? window.surface2 : window.surface1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "−"
                                    font.family: "SF Pro Text"
                                    font.pixelSize: window.s(15)
                                    font.weight: Font.Bold
                                    color: window.text
                                }

                                MouseArea {
                                    id: minusMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        let cur = parseInt(batteryInput.text) || 100;
                                        let next = Math.max(50, cur - 5);
                                        window.userModifiedBat = true;
                                        batteryInput.text = next.toString();
                                        window.selectedBatteryThreshold = next;
                                    }
                                }
                            }

                            // Numeric Input Box (50 - 100)
                            Rectangle {
                                width: window.s(66); height: window.s(28)
                                radius: window.s(6)
                                color: window.mantle
                                border.color: batteryInput.activeFocus ? window.mauve : window.surface1
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    TextInput {
                                        id: batteryInput
                                        text: window.selectedBatteryThreshold.toString()
                                        font.family: "SF Pro Text"
                                        font.pixelSize: window.s(13)
                                        font.weight: Font.Black
                                        color: window.text
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        maximumLength: 3

                                        validator: IntValidator {
                                            bottom: 50
                                            top: 100
                                        }

                                        onTextEdited: {
                                             window.userModifiedBat = true;
                                             let val = parseInt(text);
                                             if (!isNaN(val) && val >= 50 && val <= 100) {
                                                 window.selectedBatteryThreshold = val;
                                             }
                                        }

                                        onEditingFinished: {
                                            let val = parseInt(text);
                                            if (isNaN(val) || val < 50) {
                                                text = "50";
                                                window.selectedBatteryThreshold = 50;
                                            } else if (val > 100) {
                                                text = "100";
                                                window.selectedBatteryThreshold = 100;
                                            } else {
                                                window.selectedBatteryThreshold = val;
                                            }
                                            window.userModifiedBat = true;
                                        }
                                    }

                                    Text {
                                        text: "%"
                                        font.family: "SF Pro Text"
                                        font.pixelSize: window.s(11)
                                        font.weight: Font.Bold
                                        color: window.subtext0
                                    }
                                }
                            }

                            // Plus Stepper Button
                            Rectangle {
                                width: window.s(28); height: window.s(28)
                                radius: window.s(6)
                                color: plusMouse.containsMouse ? window.surface2 : window.surface1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    font.family: "SF Pro Text"
                                    font.pixelSize: window.s(15)
                                    font.weight: Font.Bold
                                    color: window.text
                                }

                                MouseArea {
                                    id: plusMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        let cur = parseInt(batteryInput.text) || 80;
                                        let next = Math.min(100, cur + 5);
                                        window.userModifiedBat = true;
                                        batteryInput.text = next.toString();
                                        window.selectedBatteryThreshold = next;
                                    }
                                }
                            }
                        }
                    }

                    // ---------------------------------------------------------
                    // 2. CPU TURBO BOOST TOGGLE SECTION
                    // ---------------------------------------------------------
                    Rectangle {
                        visible: window.hasTurbo
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(56)
                        radius: window.s(12)
                        color: Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.5)
                        border.color: window.surface1
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: window.s(12)
                            anchors.rightMargin: window.s(12)
                            spacing: window.s(10)

                            Text {
                                text: "󰓅"
                                font.family: "SF Pro "
                                font.pixelSize: window.s(18)
                                color: window.selectedTurboEnabled ? window.mauve : window.subtext0
                                Behavior on color { ColorAnimation { duration: 250 } }
                            }

                            ColumnLayout {
                                spacing: 1

                                Text {
                                    text: "CPU Turbo Boost"
                                    font.family: "SF Pro Text"
                                    font.pixelSize: window.s(13)
                                    font.weight: Font.Bold
                                    color: window.text
                                }

                                Text {
                                    text: window.selectedTurboEnabled ? "Enabled" : "Disabled"
                                    font.family: "SF Pro Text"
                                    font.pixelSize: window.s(11)
                                    color: window.selectedTurboEnabled ? window.mauve : window.subtext0
                                    Behavior on color { ColorAnimation { duration: 250 } }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Simple Toggle Switch
                            Rectangle {
                                id: turboSwitch
                                width: window.s(44); height: window.s(24)
                                radius: height / 2
                                color: window.selectedTurboEnabled ? window.mauve : window.surface2
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Rectangle {
                                    id: switchThumb
                                    width: window.s(18); height: window.s(18)
                                    radius: width / 2
                                    color: window.base
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: window.selectedTurboEnabled ? (parent.width - width - window.s(3)) : window.s(3)
                                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        window.userModifiedTurbo = true;
                                        window.selectedTurboEnabled = !window.selectedTurboEnabled;
                                    }
                                }
                            }
                        }
                    }

                    // ---------------------------------------------------------
                    // 3. AUTHENTICATION & APPLY ACTION BAR (Static, never shifted)
                    // ---------------------------------------------------------
                    Rectangle {
                        visible: window.hasBatteryThreshold || window.hasTurbo
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(48)
                        radius: window.s(12)
                        color: Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.7)
                        border.color: window.showStatus ? (window.isStatusSuccess ? window.green : window.red) : window.surface1
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: window.s(6)
                            spacing: window.s(8)

                            // Password Input Box
                            Rectangle {
                                Layout.fillWidth: true
                                height: window.s(34)
                                radius: window.s(8)
                                color: window.mantle
                                border.color: window.showStatus && !window.isStatusSuccess ? window.red : (passInput.activeFocus ? window.mauve : window.surface1)
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: window.s(8)
                                    anchors.rightMargin: window.s(6)
                                    spacing: window.s(6)

                                    Text {
                                        text: window.showStatus ? (window.isStatusSuccess ? "✓" : "✗") : "󰌾"
                                        font.family: "SF Pro "
                                        font.pixelSize: window.s(13)
                                        color: window.showStatus ? (window.isStatusSuccess ? window.green : window.red) : (passInput.activeFocus ? window.mauve : window.overlay1)
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }

                                    TextInput {
                                        id: passInput
                                        Layout.fillWidth: true
                                        echoMode: window.showPassword ? TextInput.Normal : TextInput.Password
                                        font.family: "SF Pro Text"
                                        font.pixelSize: window.s(12)
                                        color: window.text
                                        selectByMouse: true
                                        verticalAlignment: TextInput.AlignVCenter

                                        Text {
                                            anchors.fill: parent
                                            text: window.showStatus ? window.statusMessage : "Enter sudo password..."
                                            font.family: "SF Pro Text"
                                            font.pixelSize: window.s(12)
                                            color: window.showStatus ? (window.isStatusSuccess ? window.green : window.red) : window.overlay0
                                            visible: !passInput.text && !passInput.activeFocus
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onTextChanged: window.userPassword = text
                                        onAccepted: window.applyChanges()
                                    }

                                    // Eye toggle
                                    Rectangle {
                                        width: window.s(24); height: window.s(24)
                                        radius: window.s(5)
                                        color: eyeMouse.containsMouse ? window.surface1 : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: window.showPassword ? "󰈈" : "󰈉"
                                            font.family: "SF Pro "
                                            font.pixelSize: window.s(13)
                                            color: window.showPassword ? window.mauve : window.overlay1
                                        }

                                        MouseArea {
                                            id: eyeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: window.showPassword = !window.showPassword
                                        }
                                    }
                                }
                            }

                            // Apply Button with Inline Status Feedback
                            Rectangle {
                                Layout.preferredWidth: Math.max(window.s(90), applyRow.implicitWidth + window.s(20))
                                Layout.preferredHeight: window.s(34)
                                radius: window.s(8)
                                color: window.showStatus ? (window.isStatusSuccess ? window.green : window.red) : (applyMouse.containsMouse ? Qt.lighter(window.mauve, 1.15) : window.mauve)
                                opacity: window.isApplying ? 0.7 : 1.0
                                Behavior on color { ColorAnimation { duration: 200 } }

                                RowLayout {
                                    id: applyRow
                                    anchors.centerIn: parent
                                    spacing: window.s(4)

                                    Text {
                                        visible: !window.isApplying
                                        text: window.showStatus ? (window.isStatusSuccess ? "✓" : "✗") : "󰄬"
                                        font.family: "SF Pro "
                                        font.pixelSize: window.s(12)
                                        font.weight: Font.Bold
                                        color: window.crust
                                    }

                                    Text {
                                        text: window.isApplying ? "Saving..." : (window.showStatus ? (window.isStatusSuccess ? "Saved!" : "Error") : "Apply")
                                        font.family: "SF Pro Text"
                                        font.pixelSize: window.s(12)
                                        font.weight: Font.Black
                                        color: window.crust
                                    }
                                }

                                MouseArea {
                                    id: applyMouse
                                    anchors.fill: parent
                                    hoverEnabled: !window.isApplying
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.applyChanges()
                                }
                            }
                        }
                    }

                    // ---------------------------------------------------------
                    // 4. FALLBACK / NO FEATURES DETECTED
                    // ---------------------------------------------------------
                    Rectangle {
                        visible: !window.hasBatteryThreshold && !window.hasTurbo
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(48)
                        radius: window.s(12)
                        color: Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.5)
                        border.color: window.surface1
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: window.s(12)
                            anchors.rightMargin: window.s(12)
                            spacing: window.s(10)

                            Text {
                                text: "󰅙"
                                font.family: "SF Pro "
                                font.pixelSize: window.s(18)
                                color: window.subtext0
                            }

                            Text {
                                text: "No hardware controls available on this system."
                                font.family: "SF Pro Text"
                                font.pixelSize: window.s(12)
                                color: window.subtext0
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
