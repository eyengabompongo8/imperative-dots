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

    Caching { id: paths }

    // --- RECEIVE THE DBUS LIST FROM MAIN.QML ---
    property var notifModel
    property var liveNotifs

    Component.onCompleted: SysData.subscribe()
    Component.onDestruction: SysData.unsubscribe()
    property int cpuUsage: SysData.cpu
    property int ramUsage: SysData.ramPercent
    property int sysTemp: SysData.temp
    property int diskUsage: widgetCache.diskUsage

    Settings {
        id: widgetCache
        category: "SystemMonitorCache"
        property int diskUsage: 0
        property string powerProfile: "balanced"
        property int upHours: 0
        property int upMins: 0
        property real sysVolume: 0
        property bool sysMuted: false
        property real sysBrightness: 0
        property string caffeineIdle: "off"
        property bool caffeineMonitor: false
        property bool caffeineLid: false
        property bool sunsetActive: false
        property string currentUserName: "User"
    }

    // Ensure actionable notifications are continually bubbled to the top
    onNotifModelChanged: Qt.callLater(window.enforceNotificationSort)
    
    Connections {
        target: window.notifModel
        function onCountChanged() {
            Qt.callLater(window.enforceNotificationSort);
        }
    }

    function enforceNotificationSort() {
        if (!notifModel || notifModel.count <= 1) return;
        let firstNonAction = -1;
        for (let i = 0; i < notifModel.count; i++) {
            let item = notifModel.get(i);
            let hasAction = false;
            try {
                let parsed = item.actionsJson ? JSON.parse(item.actionsJson) : [];
                // Fix: Removed filter so default actions (like "Open") correctly flag the notification as actionable
                hasAction = parsed.length > 0;
            } catch(e) {}

            if (hasAction) {
                if (firstNonAction !== -1 && i > firstNonAction) {
                    notifModel.move(i, firstNonAction, 1);
                    firstNonAction++;
                }
            } else {
                if (firstNonAction === -1) {
                    firstNonAction = i;
                }
            }
        }
    }

    // --- Responsive Scaling Logic ---
    Scaler {
        id: scaler
        // Uses the physical screen width so the popup scales synchronously with the TopBar
        currentWidth: Screen.width
    }
    
    // Helper function scoped to the root Item for easy access in deeply nested elements and Canvases
    function s(val) { 
        return scaler.s(val); 
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
    // STATE & POLLING
    // -------------------------------------------------------------------------
    property bool hasBattery: false
    property int batCapacity: 0
    property string batStatus: "Unknown"
    property string powerProfile: "balanced"
    
    property int upHours: 0
    property int upMins: 0

    property real sysVolume: 0
    property bool sysMuted: false
    property real sysBrightness: 0
    property bool hasBacklight: true
    
    property string caffeineIdle: "off"
    property bool caffeineMonitor: false
    property bool caffeineLid: false
    property bool sunsetActive: false

    property string currentUserName: ""
    
    property bool dndEnabled: false

    // State object for collapsible notification groups
    property var collapsedGroups: ({})

    function toggleGroup(groupName) {
        let temp = Object.assign({}, collapsedGroups);
        temp[groupName] = !temp[groupName];
        collapsedGroups = temp;
    }

    function isCollapsed(groupName) {
        return collapsedGroups[groupName] === true;
    }

    // Anti-Jitter Sync States
    property bool isDraggingVol: false
    property bool isDraggingBri: false

    Timer { id: volSyncDelay; interval: 800; onTriggered: window.isDraggingVol = false; triggeredOnStart: true; }
    Timer { id: briSyncDelay; interval: 800; onTriggered: window.isDraggingBri = false; triggeredOnStart: true; }

    readonly property bool isCharging: batStatus === "Charging"

    // Unified hue for Battery
    readonly property color batColorStart: {
        if (!window.hasBattery) return window.blue;
        if (isCharging) return window.green;
        if (batCapacity >= 70) return window.blue;
        if (batCapacity >= 30) return window.yellow;
        return window.red;
    }
    readonly property color batColorEnd: Qt.lighter(batColorStart, 1.15)

    // Unified hue for Performance Profile
    readonly property color profileStart: {
        if (powerProfile === "performance") return window.red;
        if (powerProfile === "power-saver") return window.green;
        return window.blue;
    }
    readonly property color profileEnd: Qt.lighter(profileStart, 1.15)

    // Ambient Blobs - Based strictly on aesthetic pairs derived from battery state
    readonly property color ambientPrimary: window.batColorStart
    readonly property color ambientSecondary: {
        if (!window.hasBattery) return window.mauve;
        if (isCharging) return window.sapphire;
        if (batCapacity >= 70) return window.mauve;
        if (batCapacity >= 30) return window.peach;
        return window.maroon; 
    }

    property real animCapacity: 0
    Behavior on animCapacity { NumberAnimation { duration: 1200; easing.type: Easing.OutQuint } }
    
    onAnimCapacityChanged: batCanvas.requestPaint()
    onBatColorStartChanged: batCanvas.requestPaint()

    // --- INIT DND STATE FROM CACHE ---
    Process {
        id: dndInit
        running: true
        command: ["bash", "-c", "cat " + paths.getCacheDir("dnd") + "/state 2>/dev/null || echo '0'"]
        stdout: StdioCollector {
            onStreamFinished: {
                window.dndEnabled = (this.text.trim() === "1");
            }
        }
    }

    Process {
        id: userPoller
        command: ["bash", "-c", "echo $USER"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                window.currentUserName = this.text.trim();
            }
        }
    }

    Process {
        id: sysPoller
        command: ["bash", "-c", 
            "ls /sys/class/power_supply/BAT* 1>/dev/null 2>&1 && echo '1' || echo '0'; " +
            "(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1 | grep .) || echo '0'; " +
            "(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1 | grep .) || echo 'Unknown'; " +
            "(powerprofilesctl get 2>/dev/null | head -n1 | grep .) || echo 'balanced'; " +
            "(awk '{print int($1/3600)\"h \"int(($1%3600)/60)\"m\"}' /proc/uptime 2>/dev/null | grep .) || echo '0h 0m'; " +
            "(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100), ($3==\"[MUTED]\"?\"off\":\"on\")}' | grep .) || echo '0 on'; " +
            "(brightnessctl -m 2>/dev/null | awk -F, '{print substr($4, 1, length($4)-1)}' | grep .) || echo '0'; " +
            "caff=$(hyprcaffeine status 2>/dev/null); echo \"$caff\" | python3 -c \"import sys,re; line=sys.stdin.read(); m=re.search(r'Idle: (.+?) \\\\S+ Monitor:', line); idle=m.group(1).strip() if m else 'off'; idle=re.sub(r'[^\\\\x00-\\\\x7F\\\\s]','',idle).strip() or 'off'; mm=re.search(r'Monitor: (\\\\S+)',line); lm=re.search(r'Lid: (\\\\S+)',line); print(idle); print((mm.group(1) if mm else 'off').lower()); print((lm.group(1) if lm else 'off').lower())\"; " +
            "pidof hyprsunset >/dev/null && echo 'on' || echo 'off'; " +
            "(df -h / 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%' | grep .) || echo '0'; " +
            "ls -A /sys/class/backlight 2>/dev/null | grep -q . && echo '1' || echo '0'"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                if (lines.length >= 7) {
                    window.hasBattery = (lines[0] === "1");
                    let batCap = parseInt(lines[1]) || 0;
                    if (window.batCapacity !== batCap) {
                        window.batCapacity = batCap;
                        window.animCapacity = window.batCapacity;
                    }
                    window.batStatus = lines[2];
                    window.powerProfile = lines[3];
                    
                    let upParts = lines[4].split("h ");
                    if (upParts.length === 2) {
                        window.upHours = parseInt(upParts[0]) || 0;
                        window.upMins = parseInt(upParts[1].replace("m", "")) || 0;
                    }

                    if (!window.isDraggingVol) {
                        let volParts = (lines[5] || "0 on").trim().split(" ");
                        window.sysVolume = parseInt(volParts[0]) || 0;
                        window.sysMuted = (volParts[1] === "off");
                    }
                    
                    if (!window.isDraggingBri) {
                        window.sysBrightness = parseInt(lines[6]) || 0;
                    }
                    if (lines.length >= 10) {
                        window.caffeineIdle = (lines[7] || "off").trim();
                        window.caffeineMonitor = ((lines[8] || "off").trim() === "on");
                        window.caffeineLid = ((lines[9] || "off").trim() === "on");
                        window.sunsetActive = ((lines[10] || "off").trim().toLowerCase() === "on");
                    }
                    if (lines.length >= 12) {
                        widgetCache.diskUsage = parseInt(lines[11]) || 0;
                    }
                    if (lines.length > 0) {
                        window.hasBacklight = (lines[lines.length - 1] === "1");
                    }
                }
            }
        }
    }
    Timer {
        interval: 1500; running: true; repeat: true; triggeredOnStart: true;
        onTriggered: sysPoller.running = true
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
    }

    // --- ENHANCED STARTUP ANIMATION STATES ---
    property real introMain: 0
    property real introTop: 0
    property real introNotifs: 0
    property real introCore: 0
    property real introSliders: 0
    property real introActions: 0
    property real introProfiles: 0

    ParallelAnimation {
        running: true

        // Base window fades, scales, and lifts
        NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutQuart }

        // Top bar drops in
        SequentialAnimation {
            PauseAnimation { duration: 100 }
            NumberAnimation { target: window; property: "introTop"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
        }

        // Notification List cascades in smoothly
        SequentialAnimation {
            PauseAnimation { duration: 150 }
            NumberAnimation { target: window; property: "introNotifs"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutQuart }
        }

        // Central core pops out and breathes
        SequentialAnimation {
            PauseAnimation { duration: 250 }
            NumberAnimation { target: window; property: "introCore"; from: 0; to: 1.0; duration: 900; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }

        // Hardware sliders slide up
        SequentialAnimation {
            PauseAnimation { duration: 350 }
            NumberAnimation { target: window; property: "introSliders"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutQuart }
        }

        // Actions waterfall
        SequentialAnimation {
            PauseAnimation { duration: 450 }
            NumberAnimation { target: window; property: "introActions"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutExpo }
        }

        // Power profiles finish the wave
        SequentialAnimation {
            PauseAnimation { duration: 550 }
            NumberAnimation { target: window; property: "introProfiles"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
        }
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: window; property: "introMain"; to: 0; duration: 400; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introTop"; to: 0; duration: 300; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introNotifs"; to: 0; duration: 300; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introCore"; to: 0; duration: 350; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introSliders"; to: 0; duration: 250; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introActions"; to: 0; duration: 200; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introProfiles"; to: 0; duration: 150; easing.type: Easing.InQuart }
    }

    // Helper: Safely clear an entire group of notifications by AppName
    function clearGroup(appName) {
        if (!notifModel) return;
        for (let i = notifModel.count - 1; i >= 0; i--) {
            if (notifModel.get(i).appName === appName) {
                let uid = notifModel.get(i).uid;
                if (window.liveNotifs && window.liveNotifs[uid]) {
                    delete window.liveNotifs[uid];
                }
                notifModel.remove(i);
            }
        }
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.92 + (0.08 * introMain)
        opacity: introMain
        transform: Translate { y: window.s(15) * (1 - introMain) }

        // Unified Outer Background
        Rectangle {
            anchors.fill: parent
            radius: window.s(20)
            color: window.base
            border.color: window.surface0 
            border.width: 1
            clip: true

            // Rotating Background Blobs - Spanning across the whole widget natively
            Rectangle {
                width: parent.width * 0.8; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * window.s(150)
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * window.s(100)
                opacity: 0.08
                color: window.ambientPrimary
                Behavior on color { ColorAnimation { duration: 1000 } }
            }
            
            Rectangle {
                width: parent.width * 0.9; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * window.s(-150)
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * window.s(-100)
                opacity: 0.06
                color: window.ambientSecondary
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            RowLayout {
                anchors.fill: parent
                spacing: window.s(15) // Seamless separation instead of a line

                // ==========================================
                // HARDWARE & BATTERY CORE
                // ==========================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Radar Rings (Centered on the Hardware Panel so it aligns perfectly with the gauge)
                    Item {
                        anchors.fill: parent
                        
                        Repeater {
                            model: 3
                            Rectangle {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: window.s(-150)
                                width: window.s(230) + (index * window.s(130))
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.color: window.surface1
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: 1000 } }
                                opacity: 0.15 - (index * 0.04)
                            }
                        }
                    }

                    // TOP: UPTIME COMPONENT
                    Row {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: window.s(25)
                        spacing: window.s(6)
                        
                        transform: Translate { y: window.s(-20) * (1.0 - introTop) }
                        opacity: introTop
                        
                        // Hours Box
                        Rectangle {
                            width: window.s(44); height: window.s(48); radius: window.s(10)
                            color: window.surface0; border.color: window.surface1; border.width: 1
                            
                            Rectangle { anchors.fill: parent; radius: window.s(10); color: window.ambientPrimary; opacity: 0.05; Behavior on color { ColorAnimation { duration: 1000 } } }
                            Column {
                                anchors.centerIn: parent
                                Text { 
                                    text: window.upHours.toString().padStart(2, '0')
                                    font.pixelSize: window.s(18); font.family: "SF Mono"; font.weight: Font.Black
                                    color: window.ambientPrimary
                                    Behavior on color { ColorAnimation { duration: 1000 } }
                                    anchors.horizontalCenter: parent.horizontalCenter 
                                }
                                Text { 
                                    text: "HR"; font.pixelSize: window.s(8); font.family: "SF Pro Text"; font.weight: Font.Bold
                                    color: window.subtext0; anchors.horizontalCenter: parent.horizontalCenter 
                                }
                            }
                        }

                        // Pulsing Colon
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ":"
                            font.pixelSize: window.s(22); font.family: "SF Pro Text"; font.weight: Font.Black
                            color: window.ambientPrimary
                            Behavior on color { ColorAnimation { duration: 1000 } }
                            
                            opacity: uptimePulse
                            property real uptimePulse: 1.0
                            SequentialAnimation on uptimePulse {
                                loops: Animation.Infinite; running: true
                                NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                            }
                        }

                        // Mins Box
                        Rectangle {
                            width: window.s(44); height: window.s(48); radius: window.s(10)
                            color: window.surface0; border.color: window.surface1; border.width: 1
                            
                            Rectangle { anchors.fill: parent; radius: window.s(10); color: window.ambientSecondary; opacity: 0.05; Behavior on color { ColorAnimation { duration: 1000 } } }
                            Column {
                                anchors.centerIn: parent
                                Text { 
                                    text: window.upMins.toString().padStart(2, '0')
                                    font.pixelSize: window.s(18); font.family: "SF Pro Text"; font.weight: Font.Black
                                    color: window.ambientSecondary
                                    Behavior on color { ColorAnimation { duration: 1000 } }
                                    anchors.horizontalCenter: parent.horizontalCenter 
                                }
                                Text { 
                                    text: "MIN"; font.pixelSize: window.s(8); font.family: "SF Pro Text"; font.weight: Font.Bold
                                    color: window.subtext0; anchors.horizontalCenter: parent.horizontalCenter 
                                }
                            }
                        }
                    }

                    // Expanding top-right logout icon with hold-to-confirm left-to-right fill animation
                    Rectangle {
                        id: logoutBtn
                        anchors.top: parent.top; anchors.right: parent.right
                        anchors.margins: window.s(25)
                        width: logoutMa.containsMouse ? window.s(44) + usernameText.implicitWidth + window.s(12) : window.s(44)
                        height: window.s(44); radius: window.s(14)
                        
                        property color c1: window.red
                        property color c2: Qt.lighter(c1, 1.2)
                        
                        color: logoutMa.containsMouse ? window.surface1 : "transparent"
                        border.color: logoutMa.containsMouse ? c1 : "transparent"
                        border.width: logoutMa.containsMouse ? 2 : 1
                        clip: true
                        
                        transform: Translate { y: window.s(-20) * (1.0 - introTop) }
                        opacity: introTop

                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        
                        scale: logoutMa.pressed ? 0.96 : (logoutMa.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }

                        property real fillLevel: 0.0
                        property bool triggered: false
                        property real flashOpacity: 0.0

                        Canvas {
                            id: logoutWaveCanvas
                            anchors.fill: parent
                            
                            property real wavePhase: 0.0
                            NumberAnimation on wavePhase {
                                running: logoutBtn.fillLevel > 0.0 && logoutBtn.fillLevel < 1.0
                                loops: Animation.Infinite
                                from: 0; to: Math.PI * 2; duration: 800
                            }
                            onWavePhaseChanged: requestPaint()
                            Connections { target: logoutBtn; function onFillLevelChanged() { logoutWaveCanvas.requestPaint() } }
                            
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                if (logoutBtn.fillLevel <= 0.001) return;
                                
                                var r = window.s(14); 
                                var fillX = width * logoutBtn.fillLevel;
                                ctx.save();
                                ctx.beginPath();
                                ctx.moveTo(r, 0);
                                ctx.lineTo(width - r, 0);
                                ctx.arcTo(width, 0, width, r, r);
                                ctx.lineTo(width, height - r);
                                ctx.arcTo(width, height, width - r, height, r);
                                ctx.lineTo(r, height);
                                ctx.arcTo(0, height, 0, height - r, r);
                                ctx.lineTo(0, r);
                                ctx.arcTo(0, 0, r, 0, r);
                                ctx.closePath();
                                ctx.clip(); 
                                
                                ctx.beginPath();
                                ctx.moveTo(fillX, 0);
                                if (logoutBtn.fillLevel < 0.99) {
                                    var waveAmp = window.s(8) * Math.sin(logoutBtn.fillLevel * Math.PI); 
                                    var cp1x = fillX + Math.sin(wavePhase) * waveAmp;
                                    var cp2x = fillX + Math.cos(wavePhase + Math.PI) * waveAmp;
                                    ctx.bezierCurveTo(cp2x, height * 0.33, cp1x, height * 0.66, fillX, height);
                                    ctx.lineTo(0, height);
                                    ctx.lineTo(0, 0);
                                } else {
                                    ctx.lineTo(width, 0);
                                    ctx.lineTo(width, height);
                                    ctx.lineTo(0, height);
                                    ctx.lineTo(0, 0);
                                }
                                ctx.closePath();
                                
                                var grad = ctx.createLinearGradient(0, 0, width, 0);
                                grad.addColorStop(0, logoutBtn.c1.toString());
                                grad.addColorStop(1, logoutBtn.c2.toString());
                                ctx.fillStyle = grad;
                                ctx.fill();
                                ctx.restore();
                            }
                        }

                        Rectangle {
                            anchors.fill: parent; radius: window.s(14); color: "#ffffff"
                            opacity: logoutBtn.flashOpacity
                            PropertyAnimation on opacity { id: logoutFlashAnim; to: 0; duration: 500; easing.type: Easing.OutExpo }
                        }

                        // Base unfilled text layout
                        Row {
                            id: baseTextRow
                            anchors.right: parent.right
                            anchors.rightMargin: window.s(13)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: window.s(12)

                            Text {
                                id: usernameText
                                text: window.currentUserName
                                font.family: "SF Pro Text"
                                font.weight: Font.Bold
                                font.pixelSize: window.s(14)
                                color: window.text
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: logoutMa.containsMouse ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 250 } }
                            }

                            Text {
                                font.family: "SF Pro "; font.pixelSize: window.s(18)
                                color: logoutMa.containsMouse ? window.red : window.overlay0
                                text: "󰍃"
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        // Filled contrast text layout (clipped to width * fillLevel)
                        Item {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: logoutBtn.width * logoutBtn.fillLevel
                            clip: true

                            Row {
                                x: baseTextRow.x
                                y: baseTextRow.y
                                spacing: baseTextRow.spacing

                                Text {
                                    text: window.currentUserName
                                    font.family: "SF Pro Text"
                                    font.weight: Font.Bold
                                    font.pixelSize: window.s(14)
                                    color: window.crust
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: usernameText.opacity
                                }

                                Text {
                                    font.family: "SF Pro "; font.pixelSize: window.s(18)
                                    color: window.crust
                                    text: "󰍃"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        MouseArea {
                            id: logoutMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: logoutBtn.triggered ? Qt.ArrowCursor : Qt.PointingHandCursor
                            
                            onPressed: {
                                if (!logoutBtn.triggered) {
                                    logoutDrainAnim.stop();
                                    logoutFillAnim.start();
                                }
                            }
                            onReleased: {
                                if (!logoutBtn.triggered && logoutBtn.fillLevel < 1.0) {
                                    logoutFillAnim.stop();
                                    logoutDrainAnim.start();
                                }
                            }
                        }

                        NumberAnimation {
                            id: logoutFillAnim; target: logoutBtn; property: "fillLevel"; to: 1.0
                            duration: 900 * (1.0 - logoutBtn.fillLevel); easing.type: Easing.InSine
                            onFinished: {
                                logoutBtn.triggered = true; logoutBtn.flashOpacity = 0.6; logoutFlashAnim.start();
                                exitAnim.start(); logoutExitTimer.start();
                            }
                        }

                        NumberAnimation {
                            id: logoutDrainAnim; target: logoutBtn; property: "fillLevel"; to: 0.0
                            duration: 1500 * logoutBtn.fillLevel; easing.type: Easing.OutQuad
                        }

                        Timer {
                            id: logoutExitTimer; interval: 500
                            onTriggered: {
                                Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/exit.sh"]);
                                Quickshell.execDetached(["sh", "-c", "echo 'close' > " + paths.runDir + "/widget_state"]);
                            }
                        }
                    }

                    // CENTRAL CORE & BATTERY RING 
                    Item {
                        anchors.fill: parent
                        z: 1
                        
                        opacity: introCore
                        transform: Translate { y: window.s(25) * (1 - introCore) }
                        scale: 0.9 + (0.1 * introCore)

                        // CLEAN OUTSIDE GLOW HALO
                        Rectangle {
                            anchors.centerIn: centralCore
                            width: centralCore.width + window.s(45)
                            height: width
                            radius: width / 2
                            color: centralCore.isDangerState ? window.red : window.ambientPrimary
                            opacity: centralCore.isDangerState ? 0.25 : 0.15
                            z: 0 
                            Behavior on color { ColorAnimation { duration: 400 } }
                            SequentialAnimation on scale {
                                loops: Animation.Infinite; running: true
                                NumberAnimation { to: heroMa.containsMouse ? 1.15 : 1.08; duration: heroMa.containsMouse ? 800 : 2000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: heroMa.containsMouse ? 800 : 2000; easing.type: Easing.InOutSine }
                            }
                        }

                        Rectangle {
                            id: centralCore
                            width: window.s(340)
                            height: width
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: window.s(-150)
                            radius: width / 2
                            z: 1
                            
                            property bool isDangerState: window.hasBattery && !window.isCharging && window.batCapacity < 15
                            
                            SequentialAnimation on scale {
                                loops: Animation.Infinite
                                running: true
                                NumberAnimation { 
                                    to: heroMa.containsMouse ? 1.05 : (centralCore.isDangerState ? 1.04 : 1.01)
                                    duration: heroMa.containsMouse ? 1200 : (centralCore.isDangerState ? 600 : 2500)
                                    easing.type: Easing.InOutSine 
                                }
                                NumberAnimation { 
                                    to: 1.0
                                    duration: heroMa.containsMouse ? 1200 : (centralCore.isDangerState ? 600 : 2500)
                                    easing.type: Easing.InOutSine 
                                }
                            }

                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: window.surface0 }
                                GradientStop { position: 1.0; color: window.base }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: window.maroon
                                opacity: centralCore.isDangerState ? 0.15 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 1000 } }
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite; running: centralCore.isDangerState
                                    NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.15; duration: 600; easing.type: Easing.InOutSine }
                                }
                            }

                            Item {
                                anchors.fill: parent
                                
                                property real textPulse: 0.0
                                SequentialAnimation on textPulse {
                                    loops: Animation.Infinite; running: true
                                    NumberAnimation { from: 0.0; to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 1.0; to: 0.0; duration: 1200; easing.type: Easing.InOutSine }
                                }
                                
                                property real pumpPhase: 0.0
                                NumberAnimation on pumpPhase {
                                    running: heroMa.containsMouse && window.isCharging
                                    loops: Animation.Infinite
                                    from: 0.0; to: 1.0; duration: 1200
                                    easing.type: Easing.InOutSine 
                                    onStopped: batCanvas.requestPaint()
                                }
                                
                                property real dischargePhase: 1.0
                                NumberAnimation on dischargePhase {
                                    running: heroMa.containsMouse && !window.isCharging
                                    loops: Animation.Infinite
                                    from: 1.0; to: 0.0; duration: 1600
                                    easing.type: Easing.InOutSine
                                    onStopped: batCanvas.requestPaint()
                                }
                                
                                onPumpPhaseChanged: { if(heroMa.containsMouse && window.isCharging) batCanvas.requestPaint() }
                                onDischargePhaseChanged: { if(heroMa.containsMouse && !window.isCharging) batCanvas.requestPaint() }
                                
                                Canvas {
                                    id: batCanvas
                                    anchors.fill: parent
                                    rotation: 180 
                                    
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        
                                        var centerX = width / 2;
                                        var centerY = height / 2;
                                        var radius = (width / 2) - window.s(4); 
                                        var endAngle = (window.animCapacity / 100) * 2 * Math.PI;
                                        
                                        ctx.lineCap = "round";
                                        
                                        ctx.lineWidth = window.s(4);
                                        ctx.beginPath();
                                        ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
                                        ctx.strokeStyle = window.surface1;
                                        ctx.stroke();
                                        
                                        var fillGrad = ctx.createLinearGradient(0, height, width, 0);
                                        fillGrad.addColorStop(0, window.batColorStart.toString());
                                        fillGrad.addColorStop(1, window.batColorEnd.toString());

                                        ctx.globalAlpha = 1.0;
                                        ctx.lineWidth = window.s(8);
                                        ctx.beginPath();
                                        ctx.arc(centerX, centerY, radius, 0, endAngle);
                                        ctx.strokeStyle = fillGrad;
                                        ctx.stroke();
                                        
                                        if (heroMa.containsMouse && endAngle > 0.1) {
                                            if (window.isCharging) {
                                                var surgeAngle = parent.pumpPhase * (endAngle + 0.6) - 0.3;
                                                if (surgeAngle > 0 && surgeAngle < endAngle) {
                                                    var sStart = Math.max(0, surgeAngle - 0.4);
                                                    var sEnd = Math.min(endAngle, surgeAngle + 0.4);
                                                    ctx.beginPath();
                                                    ctx.arc(centerX, centerY, radius, sStart, sEnd);
                                                    ctx.lineWidth = window.s(12);
                                                    ctx.strokeStyle = window.batColorStart.toString();
                                                    ctx.globalAlpha = 0.5 * Math.sin(parent.pumpPhase * Math.PI);
                                                    ctx.stroke();

                                                    sStart = Math.max(0, surgeAngle - 0.2);
                                                    sEnd = Math.min(endAngle, surgeAngle + 0.2);
                                                    ctx.beginPath();
                                                    ctx.arc(centerX, centerY, radius, sStart, sEnd);
                                                    ctx.lineWidth = window.s(16);
                                                    ctx.strokeStyle = window.batColorEnd.toString();
                                                    ctx.globalAlpha = 0.8 * Math.sin(parent.pumpPhase * Math.PI);
                                                    ctx.stroke();
                                                }
                                                
                                                if (parent.pumpPhase > 0.7) {
                                                    var flarePhase = (parent.pumpPhase - 0.7) / 0.3;
                                                    var hitX = centerX + Math.cos(endAngle) * radius;
                                                    var hitY = centerY + Math.sin(endAngle) * radius;
                                                    ctx.beginPath();
                                                    ctx.arc(hitX, hitY, window.s(7) + (flarePhase * window.s(15)), 0, 2*Math.PI);
                                                    ctx.fillStyle = window.batColorEnd.toString();
                                                    ctx.globalAlpha = (1.0 - flarePhase) * 0.6;
                                                    ctx.fill();
                                                }
                                            } else {
                                                var drainCenter = parent.dischargePhase * endAngle;
                                                for (var d = 0; d < 2; d++) {
                                                    var dSpread = 0.2 + (d * 0.15);
                                                    var dStart = Math.max(0, drainCenter - dSpread);
                                                    var dEnd = Math.min(endAngle, drainCenter + dSpread);
                                                    
                                                    if (dStart < dEnd) {
                                                        ctx.beginPath();
                                                        ctx.arc(centerX, centerY, radius, dStart, dEnd);
                                                        ctx.lineWidth = window.s(8) + (1 - d) * window.s(2);
                                                        ctx.strokeStyle = window.batColorEnd.toString();
                                                        ctx.globalAlpha = 0.2 * Math.sin(parent.dischargePhase * Math.PI);
                                                        ctx.stroke();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: heroMa
                                    anchors.fill: parent 
                                    hoverEnabled: true
                                    onEntered: batCanvas.requestPaint()
                                    onExited: batCanvas.requestPaint()
                                }

                                  Grid {
                                      id: sysRow
                                      columns: 2
                                      spacing: window.s(20)
                                      anchors.centerIn: parent
                                      z: 1

                                  opacity: introCore
                                  transform: Translate { y: window.s(25) * (1 - introCore) }
                                  scale: 0.9 + (0.1 * introCore)

                                  // 1. CPU Orb
                                  Item {
                                    id: cpuOrb; width: window.s(105); height: window.s(105)
                                    property real animVal: window.cpuUsage
                                    Behavior on animVal { NumberAnimation { duration: 1200; easing.type: Easing.OutQuint } }
                                    onAnimValChanged: cpuCanvas.requestPaint()

                                    scale: cpuMa.containsMouse ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }

                                    // Individual Aura - Fixed Overlap
                                    Rectangle {
                                      anchors.centerIn: parent
                                      width: parent.width + (cpuMa.containsMouse ? window.s(16) : window.s(4)) 
                                      height: width; radius: width / 2
                                      color: window.blue
                                      opacity: cpuMa.containsMouse ? 0.25 : 0.08
                                      Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                                      Behavior on opacity { NumberAnimation { duration: 300 } }
                                    }

                                    Canvas {
                                      id: cpuCanvas; anchors.fill: parent; rotation: 180
                                      Connections { target: window; function onBaseChanged() { cpuCanvas.requestPaint() } }
                                      onPaint: {
                                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                                        var cX = width/2; var cY = height/2; var rad = (width/2)-window.s(6);
                                        var eA = (Math.min(100, Math.max(0, parent.animVal)) / 100) * 2 * Math.PI;
                                        ctx.lineCap = "round"; ctx.lineWidth = window.s(4); ctx.beginPath(); ctx.arc(cX, cY, rad, 0, 2*Math.PI); 
                                        ctx.strokeStyle = window.surface0.toString(); ctx.stroke();
                                        var grad = ctx.createLinearGradient(0, height, width, 0); grad.addColorStop(0, window.blue.toString()); grad.addColorStop(1, window.sapphire.toString());
                                        ctx.lineWidth = window.s(8); ctx.beginPath(); ctx.arc(cX, cY, rad, 0, eA); ctx.strokeStyle = grad; ctx.stroke();
                                      }
                                    }
                                    ColumnLayout {
                                      anchors.centerIn: parent; spacing: 0
                                      RowLayout {
                                        Layout.alignment: Qt.AlignHCenter; spacing: window.s(4)
                                        Text { font.family: "SF Pro "; font.pixelSize: window.s(18); color: window.blue; text: "" }
                                        Text { font.family: "SF Pro Compact"; font.weight: Font.Black; font.pixelSize: window.s(22); color: window.text; text: Math.round(cpuOrb.animVal) + "%" }
                                      }
                                      Text { Layout.alignment: Qt.AlignHCenter; font.family: "SF Pro Text"; font.weight: Font.Bold; font.pixelSize: window.s(10); color: window.subtext0; text: "CPU LOAD" }
                                    }
                                    MouseArea { id: cpuMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                                  }

                                  // 2. RAM Orb
                                  Item {
                                    id: ramOrb; width: window.s(105); height: window.s(105)
                                    property real animVal: window.ramUsage
                                    Behavior on animVal { NumberAnimation { duration: 1200; easing.type: Easing.OutQuint } }
                                    onAnimValChanged: ramCanvas.requestPaint()

                                    scale: ramMa.containsMouse ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }

                                    // Individual Aura - Fixed Overlap
                                    Rectangle {
                                      anchors.centerIn: parent
                                      width: parent.width + (ramMa.containsMouse ? window.s(16) : window.s(4))
                                      height: width; radius: width / 2
                                      color: window.mauve
                                      opacity: ramMa.containsMouse ? 0.25 : 0.08
                                      Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                                      Behavior on opacity { NumberAnimation { duration: 300 } }
                                    }

                                    Canvas {
                                      id: ramCanvas; anchors.fill: parent; rotation: 180
                                      Connections { target: window; function onBaseChanged() { ramCanvas.requestPaint() } }
                                      onPaint: {
                                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                                        var cX = width/2; var cY = height/2; var rad = (width/2)-window.s(6);
                                        var eA = (Math.min(100, Math.max(0, parent.animVal)) / 100) * 2 * Math.PI;
                                        ctx.lineCap = "round"; ctx.lineWidth = window.s(4); ctx.beginPath(); ctx.arc(cX, cY, rad, 0, 2*Math.PI); 
                                        ctx.strokeStyle = window.surface0.toString(); ctx.stroke();
                                        var grad = ctx.createLinearGradient(0, height, width, 0); grad.addColorStop(0, window.mauve.toString()); grad.addColorStop(1, window.pink.toString());
                                        ctx.lineWidth = window.s(8); ctx.beginPath(); ctx.arc(cX, cY, rad, 0, eA); ctx.strokeStyle = grad; ctx.stroke();
                                      }
                                    }
                                    ColumnLayout {
                                      anchors.centerIn: parent; spacing: 0
                                      RowLayout {
                                        Layout.alignment: Qt.AlignHCenter; spacing: window.s(4)
                                        Text { font.family: "SF Pro "; font.pixelSize: window.s(18); color: window.mauve; text: "󰍛" }
                                        Text { font.family: "SF Pro Compact"; font.weight: Font.Black; font.pixelSize: window.s(22); color: window.text; text: Math.round(ramOrb.animVal) + "%" }
                                      }
                                      Text { Layout.alignment: Qt.AlignHCenter; font.family: "SF Pro Text"; font.weight: Font.Bold; font.pixelSize: window.s(10); color: window.subtext0; text: "MEMORY" }
                                    }
                                    MouseArea { id: ramMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                                  }

                                  // 3. DISK Orb
                                  Item {
                                    id: diskOrb; width: window.s(105); height: window.s(105)
                                    property real animVal: window.diskUsage
                                    Behavior on animVal { NumberAnimation { duration: 1200; easing.type: Easing.OutQuint } }
                                    onAnimValChanged: diskCanvas.requestPaint()

                                    scale: diskMa.containsMouse ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }

                                    // Individual Aura - Fixed Overlap
                                    Rectangle {
                                      anchors.centerIn: parent
                                      width: parent.width + (diskMa.containsMouse ? window.s(16) : window.s(4))
                                      height: width; radius: width / 2
                                      color: window.peach
                                      opacity: diskMa.containsMouse ? 0.25 : 0.08
                                      Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                                      Behavior on opacity { NumberAnimation { duration: 300 } }
                                    }

                                    Canvas {
                                      id: diskCanvas; anchors.fill: parent; rotation: 180
                                      Connections { target: window; function onBaseChanged() { diskCanvas.requestPaint() } }
                                      onPaint: {
                                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                                        var cX = width/2; var cY = height/2; var rad = (width/2)-window.s(6);
                                        var eA = (Math.min(100, Math.max(0, parent.animVal)) / 100) * 2 * Math.PI;
                                        ctx.lineCap = "round"; ctx.lineWidth = window.s(4); ctx.beginPath(); ctx.arc(cX, cY, rad, 0, 2*Math.PI); 
                                        ctx.strokeStyle = window.surface0.toString(); ctx.stroke();
                                        var grad = ctx.createLinearGradient(0, height, width, 0); grad.addColorStop(0, window.peach.toString()); grad.addColorStop(1, window.yellow.toString());
                                        ctx.lineWidth = window.s(8); ctx.beginPath(); ctx.arc(cX, cY, rad, 0, eA); ctx.strokeStyle = grad; ctx.stroke();
                                      }
                                    }
                                    ColumnLayout {
                                      anchors.centerIn: parent; spacing: 0
                                      RowLayout {
                                        Layout.alignment: Qt.AlignHCenter; spacing: window.s(4)
                                        Text { font.family: "SF Pro "; font.pixelSize: window.s(18); color: window.peach; text: "󰋊" }
                                        Text { font.family: "SF Pro Compact"; font.weight: Font.Black; font.pixelSize: window.s(22); color: window.text; text: Math.round(diskOrb.animVal) + "%" }
                                      }
                                      Text { Layout.alignment: Qt.AlignHCenter; font.family: "SF Pro Text"; font.weight: Font.Bold; font.pixelSize: window.s(10); color: window.subtext0; text: "STORAGE" }
                                    }
                                    MouseArea { id: diskMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                                  }

                                  // 4. TEMP Orb
                                  Item {
                                    id: tempOrb; width: window.s(105); height: window.s(105)
                                    property real animVal: window.sysTemp
                                    Behavior on animVal { NumberAnimation { duration: 1200; easing.type: Easing.OutQuint } }
                                    onAnimValChanged: tempCanvas.requestPaint()

                                    scale: tempMa.containsMouse ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }

                                    // Individual Aura - Fixed Overlap
                                    Rectangle {
                                      anchors.centerIn: parent
                                      width: parent.width + (tempMa.containsMouse ? window.s(16) : window.s(4))
                                      height: width; radius: width / 2
                                      color: window.red
                                      opacity: tempMa.containsMouse ? 0.25 : 0.08
                                      Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                                      Behavior on opacity { NumberAnimation { duration: 300 } }
                                    }

                                    Canvas {
                                      id: tempCanvas; anchors.fill: parent; rotation: 180
                                      Connections { target: window; function onBaseChanged() { tempCanvas.requestPaint() } }
                                      onPaint: {
                                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                                        var cX = width/2; var cY = height/2; var rad = (width/2)-window.s(6);
                                        var eA = (Math.min(100, Math.max(0, parent.animVal)) / 100) * 2 * Math.PI;
                                        ctx.lineCap = "round"; ctx.lineWidth = window.s(4); ctx.beginPath(); ctx.arc(cX, cY, rad, 0, 2*Math.PI); 
                                        ctx.strokeStyle = window.surface0.toString(); ctx.stroke();
                                        var grad = ctx.createLinearGradient(0, height, width, 0); grad.addColorStop(0, window.red.toString()); grad.addColorStop(1, window.maroon.toString());
                                        ctx.lineWidth = window.s(8); ctx.beginPath(); ctx.arc(cX, cY, rad, 0, eA); ctx.strokeStyle = grad; ctx.stroke();
                                      }
                                    }
                                    ColumnLayout {
                                      anchors.centerIn: parent; spacing: 0
                                      RowLayout {
                                        Layout.alignment: Qt.AlignHCenter; spacing: window.s(4)
                                        Text { font.family: "SF Pro "; font.pixelSize: window.s(18); color: window.red; text: "" }
                                        Text { font.family: "SF Pro Compact"; font.weight: Font.Black; font.pixelSize: window.s(22); color: window.text; text: Math.round(tempOrb.animVal) + "°" }
                                      }
                                      Text { Layout.alignment: Qt.AlignHCenter; font.family: "SF Pro Text"; font.weight: Font.Bold; font.pixelSize: window.s(10); color: window.subtext0; text: "SYSTEM TEMP" }
                                    }
                                    MouseArea { id: tempMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                                  }
                                }
                            }
                        }

                        ColumnLayout {
                            visible: window.hasBattery && window.batCapacity > 0
                            anchors.right: parent.right
                            anchors.rightMargin: window.s(30)
                            anchors.bottom: centralCore.bottom
                            anchors.bottomMargin: window.s(-15)
                            spacing: 0
                            
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter; spacing: window.s(4)
                                Text { font.family: "SF Pro "; font.pixelSize: window.s(18); color: window.isCharging ? window.green : window.ambientPrimary; text: window.isCharging ? "󰂄" : "󰁹"; Behavior on color { ColorAnimation { duration: 400 } } }
                                Text { font.family: "SF Pro Compact"; font.weight: Font.Black; font.pixelSize: window.s(22); color: window.text; text: Math.round(window.animCapacity) + "%" }
                            }
                            Text { Layout.alignment: Qt.AlignHCenter; font.family: "SF Pro Text"; font.weight: Font.Bold; font.pixelSize: window.s(10); color: window.subtext0; text: "BATTERY" }
                        }

                        // BOTTOM DOCKS
                        ColumnLayout {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: window.s(20)
                            spacing: window.s(10)

                            // 1. HARDWARE CONTROLS DOCK (Sliders)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: window.hasBacklight ? window.s(96) : window.s(52)
                                radius: window.s(14)
                                color: window.surface0
                                border.color: window.surface1
                                border.width: 1

                                opacity: introSliders
                                transform: Translate { y: window.s(20) * (1.0 - introSliders) }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: window.s(14)
                                    spacing: window.s(12)

                                    // Brightness Slider
                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: window.hasBacklight
                                        spacing: window.s(15)

                                        Item {
                                            Layout.preferredWidth: window.s(32)
                                            Layout.preferredHeight: window.s(32)
                                            Text {
                                                anchors.centerIn: parent
                                                text: window.sysBrightness > 66 ? "󰃠" : (window.sysBrightness > 33 ? "󰃟" : "󰃞")
                                                font.family: "SF Pro "
                                                font.pixelSize: window.s(22)
                                                color: window.ambientPrimary
                                                Behavior on color { ColorAnimation { duration: 200 } }
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            height: window.s(18)
                                            
                                            Timer {
                                                id: briCmdThrottle
                                                interval: 50
                                                property int targetPct: -1
                                                onTriggered: {
                                                    if (targetPct >= 0) {
                                                        Quickshell.execDetached(["brightnessctl", "set", targetPct + "%"]);
                                                        targetPct = -1;
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: window.s(9)
                                                color: window.surface1
                                                border.color: window.surface2
                                                border.width: 1
                                                clip: true

                                                Rectangle {
                                                    height: parent.height
                                                    width: parent.width * (window.sysBrightness / 100)
                                                    radius: window.s(9)
                                                    opacity: briMa.containsMouse ? 1.0 : 0.85
                                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                                    Behavior on width { enabled: !window.isDraggingBri; NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

                                                    gradient: Gradient {
                                                        orientation: Gradient.Horizontal
                                                        GradientStop { position: 0.0; color: window.batColorStart; Behavior on color { ColorAnimation { duration: 300 } } }
                                                        GradientStop { position: 1.0; color: window.batColorEnd; Behavior on color { ColorAnimation { duration: 300 } } }
                                                    }
                                                }
                                            }
                                            MouseArea {
                                                id: briMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onPressed: (mouse) => { briSyncDelay.stop(); window.isDraggingBri = true; updateBri(mouse.x); }
                                                onPositionChanged: (mouse) => { if (pressed) updateBri(mouse.x); }
                                                onReleased: { briSyncDelay.restart(); }
                                                
                                                function updateBri(mx) {
                                                    let pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));
                                                    window.sysBrightness = pct; 
                                                    briCmdThrottle.targetPct = pct;
                                                    if (!briCmdThrottle.running) briCmdThrottle.start();
                                                }
                                            }
                                        }
                                    }

                                    // Volume Slider
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: window.s(15)

                                        Rectangle {
                                            Layout.preferredWidth: window.s(32)
                                            Layout.preferredHeight: window.s(32)
                                            radius: window.s(16)
                                            color: volIconMa.containsMouse ? window.surface1 : "transparent"
                                            border.color: volIconMa.containsMouse ? window.profileStart : "transparent"
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: window.sysMuted || window.sysVolume === 0 ? "󰖁" : (window.sysVolume > 50 ? "󰕾" : "󰖀")
                                                font.family: "SF Pro "
                                                font.pixelSize: window.s(22)
                                                color: window.sysMuted ? window.overlay0 : window.profileStart
                                                Behavior on color { ColorAnimation { duration: 200 } }
                                            }
                                            MouseArea {
                                                id: volIconMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    volSyncDelay.stop();
                                                    window.isDraggingVol = true; 
                                                    window.sysMuted = !window.sysMuted;
                                                    Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
                                                    volSyncDelay.restart();
                                                }
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            height: window.s(18)
                                            
                                            Timer {
                                                id: volCmdThrottle
                                                interval: 50
                                                property int targetPct: -1
                                                onTriggered: {
                                                    if (targetPct >= 0) {
                                                        if (targetPct > 0 && window.sysMuted) {
                                                            window.sysMuted = false;
                                                            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"]);
                                                        }
                                                        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", targetPct + "%"]);
                                                        targetPct = -1;
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: window.s(9)
                                                color: window.surface1
                                                border.color: window.surface2
                                                border.width: 1
                                                clip: true

                                                Rectangle {
                                                    height: parent.height
                                                    width: parent.width * (window.sysVolume / 100)
                                                    radius: window.s(9)
                                                    opacity: window.sysMuted ? 0.5 : (volMa.containsMouse ? 1.0 : 0.85)
                                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                                    Behavior on width { enabled: !window.isDraggingVol; NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

                                                    gradient: Gradient {
                                                        orientation: Gradient.Horizontal
                                                        GradientStop { position: 0.0; color: window.sysMuted ? window.surface2 : window.profileStart; Behavior on color { ColorAnimation { duration: 300 } } }
                                                        GradientStop { position: 1.0; color: window.sysMuted ? Qt.lighter(window.surface2, 1.15) : window.profileEnd; Behavior on color { ColorAnimation { duration: 300 } } }
                                                    }
                                                }
                                            }
                                            MouseArea {
                                                id: volMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onPressed: (mouse) => { volSyncDelay.stop(); window.isDraggingVol = true; updateVol(mouse.x); }
                                                onPositionChanged: (mouse) => { if (pressed) updateVol(mouse.x); }
                                                onReleased: { volSyncDelay.restart(); }
                                                
                                                function updateVol(mx) {
                                                    let pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));
                                                    window.sysVolume = pct;
                                                    volCmdThrottle.targetPct = pct;
                                                    if (!volCmdThrottle.running) volCmdThrottle.start();
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 1.5. DISPLAY & CAFFEINE ACTIONS DOCK
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: window.s(55)
                                spacing: window.s(10)
                                
                                opacity: introActions
                                transform: Translate { y: window.s(30) * (1.0 - introActions) }

                                // SUNSET PANEL
                                Rectangle {
                                    id: sunsetBtn
                                    Layout.preferredWidth: window.s(60)
                                    Layout.fillHeight: true
                                    radius: window.s(12)
                                    color: window.sunsetActive ? window.blue : (sunsetMa.containsMouse ? window.surface1 : window.surface0)
                                    border.color: window.sunsetActive ? window.blue : (sunsetMa.containsMouse ? window.blue : window.surface2)
                                    border.width: sunsetMa.containsMouse || window.sunsetActive ? 2 : 1
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Behavior on border.color { ColorAnimation { duration: 200 } }

                                    Text {
                                        anchors.centerIn: parent
                                        font.family: "SF Pro "
                                        font.pixelSize: window.s(22)
                                        color: window.sunsetActive ? window.crust : window.text
                                        text: "󰈈"
                                    }
                                    MouseArea {
                                        id: sunsetMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Quickshell.execDetached(["sh", "-c", "(pidof hyprsunset && pkill hyprsunset) || hyprsunset"]);
                                            sysPoller.running = true;
                                        }
                                    }
                                }
                                
                                // CAFFEINE PANEL
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: window.s(12)
                                    color: window.surface0
                                    border.color: window.surface1
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: window.s(8)
                                        spacing: window.s(8)

                                        // Lid Toggle
                                        Rectangle {
                                            Layout.preferredWidth: window.s(60)
                                            Layout.fillHeight: true
                                            radius: window.s(8)
                                            color: window.caffeineLid ? window.mauve : (lidMa.containsMouse ? window.surface1 : "transparent")
                                            Text { anchors.centerIn: parent; font.family: "SF Pro "; font.pixelSize: window.s(16); color: window.caffeineLid ? window.crust : window.text; text: "󰌢" }
                                            MouseArea { id: lidMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Quickshell.execDetached(["hyprcaffeine", "lid", "toggle"]); sysPoller.running = true; } }
                                        }
                                        
                                        // Monitor Toggle
                                        Rectangle {
                                            Layout.preferredWidth: window.s(60)
                                            Layout.fillHeight: true
                                            radius: window.s(8)
                                            color: window.caffeineMonitor ? window.mauve : (monMa.containsMouse ? window.surface1 : "transparent")
                                            Text { anchors.centerIn: parent; font.family: "SF Pro "; font.pixelSize: window.s(16); color: window.caffeineMonitor ? window.crust : window.text; text: "󰍹" }
                                            MouseArea { id: monMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Quickshell.execDetached(["hyprcaffeine", "monitor", "toggle"]); sysPoller.running = true; } }
                                        }

                                        // Idle Toggle (fixed size, icon only)
                                        Rectangle {
                                            Layout.preferredWidth: window.s(60)
                                            Layout.fillHeight: true
                                            radius: window.s(8)
                                            color: window.caffeineIdle !== "off" ? window.mauve : (idleMa.containsMouse ? window.surface1 : "transparent")
                                            Text { anchors.centerIn: parent; font.family: "SF Pro "; font.pixelSize: window.s(16); color: window.caffeineIdle !== "off" ? window.crust : window.text; text: "󰛊" }
                                            MouseArea { id: idleMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Quickshell.execDetached(["hyprcaffeine", "toggle"]); sysPoller.running = true; } }
                                        }

                                        // Time Remaining Label
                                        Text {
                                            visible: window.caffeineIdle !== "off"
                                            font.family: "SF Pro Text"
                                            font.weight: Font.Bold
                                            font.pixelSize: window.s(11)
                                            color: window.subtext0
                                            Layout.alignment: Qt.AlignVCenter
                                            text: {
                                                let raw = window.caffeineIdle;
                                                if (raw === "off") return "";
                                                if (raw === "infinite") return "∞";
                                                return raw;
                                            }
                                        }

                                        // Timer Input Container
                                        Rectangle {
                                            Layout.preferredWidth: window.s(40)
                                            Layout.fillHeight: true
                                            radius: window.s(8)
                                            color: window.surface1
                                            border.color: window.surface2
                                            border.width: 1
                                            TextInput {
                                                id: timerValInput
                                                anchors.fill: parent
                                                anchors.leftMargin: window.s(4)
                                                anchors.rightMargin: window.s(4)
                                                horizontalAlignment: TextInput.AlignHCenter
                                                verticalAlignment: TextInput.AlignVCenter
                                                font.family: "SF Pro Text"; font.pixelSize: window.s(12); color: window.text
                                                text: "30"
                                                validator: IntValidator { bottom: 1; top: 999 }
                                            }
                                        }
                                        
                                        // Unit Toggle
                                        Rectangle {
                                            Layout.preferredWidth: window.s(22)
                                            Layout.fillHeight: true
                                            radius: window.s(8)
                                            color: unitMa.containsMouse ? window.surface1 : "transparent"
                                            Text { id: timerUnitTxt; anchors.centerIn: parent; font.family: "SF Pro Text"; font.weight: Font.Bold; font.pixelSize: window.s(12); color: window.subtext0; text: "m" }
                                            MouseArea { id: unitMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { timerUnitTxt.text = timerUnitTxt.text === "m" ? "h" : "m"; } }
                                        }
                                        
                                        // Apply Button
                                        Rectangle {
                                            Layout.preferredWidth: window.s(32)
                                            Layout.fillHeight: true
                                            radius: window.s(8)
                                            color: applyMa.containsMouse ? window.surface2 : window.surface1
                                            Text { anchors.centerIn: parent; font.family: "SF Pro "; font.pixelSize: window.s(16); color: window.text; text: "󰄬" }
                                            MouseArea {
                                                id: applyMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    Quickshell.execDetached(["hyprcaffeine", "on", timerValInput.text + timerUnitTxt.text]);
                                                    sysPoller.running = true;
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 2. SYSTEM ACTIONS DOCK
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: window.s(65)
                                spacing: window.s(10)
                                
                                Repeater {
                                    model: ListModel {
                                        ListElement { cmd: "bash ~/.config/hypr/scripts/lock.sh"; icon: ""; baseColor: "mauve"; weight: 1.0 }
                                        ListElement { cmd: "bash ~/.config/hypr/scripts/lock.sh & systemctl suspend-then-hibernate"; icon: "ᶻ 𝗓 𝗓"; baseColor: "blue"; weight: 1.5 }
                                        ListElement { cmd: "bash ~/.config/hypr/scripts/lock.sh & systemctl hibernate"; icon: ""; baseColor: "blue"; weight: 1.5 }
                                        ListElement { cmd: "hyprshutdown -t 'Restarting...' --post-cmd 'reboot'"; icon: "󰑓"; baseColor: "yellow"; weight: 2.5 }
                                        ListElement { cmd: "hyprshutdown -t 'Shutting down...' --post-cmd 'shutdown -P 0'"; icon: ""; baseColor: "red"; weight: 3.5 }
                                    }
                                    
                                    delegate: Rectangle {
                                        id: actionCapsule
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: window.s(12)

                                        opacity: introActions
                                        transform: Translate { y: window.s(30) * (1.0 - introActions) + (index * window.s(10) * (1.0 - introActions)) }
                                        
                                        property color c1: window[baseColor] || window.surface1
                                        property color c2: Qt.lighter(c1, 1.2)

                                        color: actionMa.containsMouse ? window.surface1 : window.surface0
                                        border.color: actionMa.containsMouse ? c1 : window.surface2
                                        border.width: actionMa.containsMouse ? 2 : 1
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                        Behavior on border.color { ColorAnimation { duration: 200 } }
                                        
                                        scale: actionMa.pressed ? (0.98 - (0.01 * weight)) : (actionMa.containsMouse ? 1.08 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }

                                        property real fillLevel: 0.0
                                        property bool triggered: false
                                        property real flashOpacity: 0.0
                                        
                                        Canvas {
                                            id: actionWaveCanvas
                                            anchors.fill: parent
                                            
                                            property real wavePhase: 0.0
                                            NumberAnimation on wavePhase {
                                                running: actionCapsule.fillLevel > 0.0 && actionCapsule.fillLevel < 1.0
                                                loops: Animation.Infinite
                                                from: 0; to: Math.PI * 2; duration: 800
                                            }
                                            onWavePhaseChanged: requestPaint()
                                            Connections { target: actionCapsule; function onFillLevelChanged() { actionWaveCanvas.requestPaint() } }
                                            
                                            onPaint: {
                                                var ctx = getContext("2d");
                                                ctx.clearRect(0, 0, width, height);
                                                if (actionCapsule.fillLevel <= 0.001) return;
                                                
                                                var r = window.s(14); 
                                                var fillY = height * (1.0 - actionCapsule.fillLevel);
                                                ctx.save();
                                                ctx.beginPath();
                                                ctx.moveTo(r, 0);
                                                ctx.lineTo(width - r, 0);
                                                ctx.arcTo(width, 0, width, r, r);
                                                ctx.lineTo(width, height - r);
                                                ctx.arcTo(width, height, width - r, height, r);
                                                ctx.lineTo(r, height);
                                                ctx.arcTo(0, height, 0, height - r, r);
                                                ctx.lineTo(0, r);
                                                ctx.arcTo(0, 0, r, 0, r);
                                                ctx.closePath();
                                                ctx.clip(); 
                                                
                                                ctx.beginPath();
                                                ctx.moveTo(0, fillY);
                                                if (actionCapsule.fillLevel < 0.99) {
                                                    var waveAmp = window.s(10) * Math.sin(actionCapsule.fillLevel * Math.PI); 
                                                    var cp1y = fillY + Math.sin(wavePhase) * waveAmp;
                                                    var cp2y = fillY + Math.cos(wavePhase + Math.PI) * waveAmp;
                                                    ctx.bezierCurveTo(width * 0.33, cp2y, width * 0.66, cp1y, width, fillY);
                                                    ctx.lineTo(width, height);
                                                    ctx.lineTo(0, height);
                                                } else {
                                                    ctx.lineTo(width, 0);
                                                    ctx.lineTo(width, height);
                                                    ctx.lineTo(0, height);
                                                }
                                                ctx.closePath();
                                                
                                                var grad = ctx.createLinearGradient(0, 0, 0, height);
                                                grad.addColorStop(0, actionCapsule.c1.toString());
                                                grad.addColorStop(1, actionCapsule.c2.toString());
                                                ctx.fillStyle = grad;
                                                ctx.fill();
                                                ctx.restore();
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent; radius: window.s(14); color: "#ffffff"
                                            opacity: actionCapsule.flashOpacity
                                            PropertyAnimation on opacity { id: cardFlashAnim; to: 0; duration: 500; easing.type: Easing.OutExpo }
                                        }

                                        Text { 
                                            anchors.centerIn: parent
                                            font.family: "SF Pro "
                                            font.pixelSize: window.s(24)
                                            color: actionMa.containsMouse ? window.text : window.subtext0
                                            text: icon
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }

                                        Item {
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                            height: actionCapsule.height * actionCapsule.fillLevel
                                            clip: true
                                            
                                            Text { 
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                y: (actionCapsule.height / 2) - (height / 2) - (actionCapsule.height - parent.height)
                                                font.family: "SF Pro "
                                                font.pixelSize: window.s(24)
                                                color: window.crust
                                                text: icon 
                                            }
                                        }

                                        MouseArea {
                                            id: actionMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: actionCapsule.triggered ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            
                                            onPressed: { 
                                                if (!actionCapsule.triggered) { 
                                                    drainAnim.stop(); 
                                                    fillAnim.start(); 
                                                }
                                            }
                                            onReleased: {
                                                if (!actionCapsule.triggered && actionCapsule.fillLevel < 1.0) { 
                                                    fillAnim.stop(); 
                                                    drainAnim.start(); 
                                                }
                                            }
                                        }

                                        NumberAnimation {
                                            id: fillAnim; target: actionCapsule; property: "fillLevel"; to: 1.0
                                            duration: (550 * weight) * (1.0 - actionCapsule.fillLevel); easing.type: Easing.InSine
                                            onFinished: {
                                                actionCapsule.triggered = true; actionCapsule.flashOpacity = 0.6; cardFlashAnim.start();
                                                exitAnim.start(); exitTimer.start(); // Start graceful exit sequence
                                            }
                                        }
                                        
                                        NumberAnimation {
                                            id: drainAnim; target: actionCapsule; property: "fillLevel"; to: 0.0
                                            duration: 1500 * actionCapsule.fillLevel; easing.type: Easing.OutQuad
                                        }

                                        Timer {
                                            id: exitTimer; interval: 500 
                                            onTriggered: { Quickshell.execDetached(["sh", "-c", cmd]); Quickshell.execDetached(["sh", "-c", "echo 'close' > " + paths.runDir + "/widget_state"]); }
                                        }
                                    }
                                }
                            }

                            // 3. POWER PROFILES DOCK
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: window.s(54)
                                radius: window.s(14)
                                color: window.surface0 
                                border.color: window.surface1
                                border.width: 1

                                opacity: introProfiles
                                transform: Translate { y: window.s(20) * (1.0 - introProfiles) }
                                
                                Rectangle {
                                    id: sliderPill
                                    width: (parent.width - window.s(2)) / 3 
                                    height: parent.height - window.s(2)
                                    y: window.s(1)
                                    radius: window.s(10)
                                    x: {
                                        if (window.powerProfile === "performance") return window.s(1);
                                        if (window.powerProfile === "balanced") return width + window.s(1);
                                        return (width * 2) + window.s(1);
                                    }
                                    
                                    Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                                    
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: window.profileStart; Behavior on color { ColorAnimation{duration:400} } }
                                        GradientStop { position: 1.0; color: window.profileEnd; Behavior on color { ColorAnimation{duration:400} } }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    Repeater {
                                        model: ListModel {
                                            ListElement { name: "performance"; icon: "󰓅"; label: "Perform" } 
                                            ListElement { name: "balanced"; icon: "󰗑"; label: "Balance" }   
                                            ListElement { name: "power-saver"; icon: "󰌪"; label: "Saver" } 
                                        }
                                        
                                        delegate: Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            
                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: window.s(8)
                                                Text {
                                                    font.family: "SF Pro "; font.pixelSize: window.s(18)
                                                    color: window.powerProfile === name ? window.crust : (profileMa.containsMouse ? window.text : window.subtext0)
                                                    text: icon
                                                    Behavior on color { ColorAnimation { duration: 200 } }
                                                }
                                                Text {
                                                    font.family: "SF Pro Text"; font.weight: Font.Black; font.pixelSize: window.s(13)
                                                    color: window.powerProfile === name ? window.crust : (profileMa.containsMouse ? window.text : window.subtext0)
                                                    text: label
                                                    Behavior on color { ColorAnimation { duration: 200 } }
                                                }
                                            }
                                            
                                            MouseArea {
                                                id: profileMa
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { Quickshell.execDetached(["powerprofilesctl", "set", name]); sysPoller.running = true; }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

