import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"

Item {
    id: root
    focus: true

    property var notifModel: null
    property var liveNotifs: null
    property real layoutWidth: 0
    property real layoutHeight: 0

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }

    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color subtext1: _theme.subtext1 || "#8f909a"
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color blue: _theme.blue || "#89b4fa"

    // Snappy switcher theme colors
    readonly property color cardBg: Qt.rgba(0.12, 0.12, 0.15, 0.70)
    readonly property color cardSelectedBg: Qt.rgba(0.20, 0.21, 0.26, 0.95)
    readonly property color cardBorderSelected: root.blue
    readonly property color cardBorderNormal: Qt.rgba(0.3, 0.3, 0.35, 0.35)

    // State & Model
    property int selectedIndex: 0
    property int currentActiveWsId: 1
    property string currentActiveWsName: "1"
    property bool isSpecialActive: false

    ListModel {
        id: windowsModel
    }

    // Dynamic sizing based on number of cards (horizontal row)
    readonly property int cardWidth: root.s(140)
    readonly property int cardHeight: root.s(130)
    readonly property int cardGap: root.s(12)
    readonly property int containerPadding: root.s(16)

    readonly property int windowCount: windowsModel.count
    readonly property real targetMasterWidth: windowCount > 0
        ? (windowCount * cardWidth) + ((windowCount - 1) * cardGap) + (containerPadding * 2)
        : root.s(280)
    readonly property real targetMasterHeight: cardHeight + (containerPadding * 2)

    // Icon resolution
    readonly property var iconOverrides: ({
        "zen": "zen-browser",
        "code": "com.visualstudio.code",
        "code-oss": "com.visualstudio.code.oss",
        "obs": "com.obsproject.Studio",
        "kitty": "kitty",
        "alacritty": "Alacritty",
        "discord": "discord",
        "spotify": "spotify",
        "nautilus": "org.gnome.Nautilus"
    })

    function resolveIcon(cls) {
        if (!cls) return "application-x-executable";
        let raw = cls.toString().trim();
        let key = raw.toLowerCase();
        if (iconOverrides[key]) return iconOverrides[key];

        if (typeof DesktopEntries !== "undefined") {
            let entry = DesktopEntries.heuristicLookup(raw) || DesktopEntries.byId(raw) || DesktopEntries.byId(key);
            if (entry && entry.icon) return entry.icon;

            if (DesktopEntries.applications && DesktopEntries.applications.values) {
                let apps = DesktopEntries.applications.values;
                for (let i = 0; i < apps.length; i++) {
                    let app = apps[i];
                    if (app && app.startupClass && app.startupClass.toLowerCase() === key) {
                        if (app.icon) return app.icon;
                    }
                }
            }
        }

        if (key.indexOf(".") !== -1) {
            let parts = key.split(".");
            let last = parts[parts.length - 1];
            if (iconOverrides[last]) return iconOverrides[last];
            if (typeof DesktopEntries !== "undefined") {
                let entry = DesktopEntries.heuristicLookup(last) || DesktopEntries.byId(last);
                if (entry && entry.icon) return entry.icon;
            }
            if (last && last.length > 2) return last;
        }

        return key;
    }

    // Identify active workspace on focused monitor (Normal vs Special)
    function detectActiveWorkspace() {
        let wsId = 1;
        let wsName = "1";
        let isSpecial = false;

        if (typeof Hyprland !== "undefined") {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.lastIpcObject) {
                let mon = Hyprland.focusedMonitor.lastIpcObject;
                if (mon.specialWorkspace && mon.specialWorkspace.id && mon.specialWorkspace.id !== 0) {
                    wsId = mon.specialWorkspace.id;
                    wsName = mon.specialWorkspace.name || ("special:" + wsId);
                    isSpecial = true;
                }
            }

            if (!isSpecial) {
                if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id) {
                    wsId = Hyprland.focusedWorkspace.id;
                    wsName = Hyprland.focusedWorkspace.name || wsId.toString();
                } else if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace && Hyprland.focusedMonitor.activeWorkspace.id) {
                    wsId = Hyprland.focusedMonitor.activeWorkspace.id;
                    wsName = Hyprland.focusedMonitor.activeWorkspace.name || wsId.toString();
                }
                if (wsName.indexOf("special:") === 0 || wsId < 0) {
                    isSpecial = true;
                }
            }
        }

        root.currentActiveWsId = wsId;
        root.currentActiveWsName = wsName;
        root.isSpecialActive = isSpecial;

        return { id: wsId, name: wsName, isSpecial: isSpecial };
    }

    // Recency tracking (MRU order)
    property var mruHistory: []

    Connections {
        target: (typeof Hyprland !== "undefined") ? Hyprland : null
        function onActiveToplevelChanged() {
            if (Hyprland && Hyprland.activeToplevel && Hyprland.activeToplevel.address) {
                let raw = Hyprland.activeToplevel.address;
                let addr = typeof raw === "number" ? ("0x" + raw.toString(16)) : (raw.toString().startsWith("0x") ? raw.toString() : ("0x" + raw.toString()));
                addr = addr.toLowerCase();
                let filtered = [addr];
                for (let i = 0; i < root.mruHistory.length; i++) {
                    if (root.mruHistory[i] !== addr) {
                        filtered.push(root.mruHistory[i]);
                    }
                }
                root.mruHistory = filtered;
            }
        }
    }

    // Refresh windows strictly scoped to current workspace & sort by MRU
    function refreshWindows() {
        if (typeof Hyprland === "undefined") return;

        let activeWs = detectActiveWorkspace();
        let targetWsId = activeWs.id;
        let toplevels = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        let list = [];

        // Currently active toplevel address
        let curActiveAddr = "";
        if (Hyprland.activeToplevel && Hyprland.activeToplevel.address) {
            let a = Hyprland.activeToplevel.address;
            curActiveAddr = (typeof a === "number" ? ("0x" + a.toString(16)) : a.toString()).toLowerCase();
        }

        for (let i = 0; i < toplevels.length; i++) {
            let t = toplevels[i];
            if (!t) continue;
            let ipc = t.lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true) continue;

            // Workspace ID resolution
            let wsId = (t.workspace && t.workspace.id !== undefined) ? t.workspace.id : (ipc.workspace ? ipc.workspace.id : 1);
            let wsName = (t.workspace && t.workspace.name) ? t.workspace.name : (ipc.workspace ? ipc.workspace.name : wsId.toString());

            // STRICT WORKSPACE SCOPE: Only include windows belonging to active workspace
            if (wsId !== targetWsId) {
                continue;
            }

            let rawAddr = (ipc && ipc.address) ? ipc.address : (t && t.address ? t.address : "");
            let addr = "";
            if (typeof rawAddr === "number") {
                addr = "0x" + rawAddr.toString(16);
            } else if (typeof rawAddr === "string" && rawAddr.length > 0) {
                addr = (rawAddr.startsWith("0x") || rawAddr.startsWith("0X")) ? rawAddr : ("0x" + rawAddr);
            }

            let cls = ipc["class"] || ipc["initialClass"] || t.appId || "Window";
            let title = t.title || ipc.title || cls;
            let icon = resolveIcon(cls);
            let focusHistory = (ipc.focusHistoryID !== undefined) ? ipc.focusHistoryID : 99;
            let isFloating = (ipc.floating !== undefined) ? ipc.floating : false;

            // Compute recency rank: 0 if currently active, otherwise index in mruHistory, fallback to focusHistory
            let lowerAddr = addr.toLowerCase();
            let recencyRank = 999;
            if (curActiveAddr && lowerAddr === curActiveAddr) {
                recencyRank = 0;
            } else {
                let mruIdx = root.mruHistory.indexOf(lowerAddr);
                if (mruIdx !== -1) {
                    recencyRank = mruIdx + 1;
                } else {
                    recencyRank = 100 + focusHistory;
                }
            }

            list.push({
                address: addr,
                className: cls,
                title: title,
                icon: icon,
                workspaceId: wsId,
                workspaceName: wsName,
                isSpecial: activeWs.isSpecial,
                isFloating: isFloating,
                focusHistory: focusHistory,
                recencyRank: recencyRank
            });
        }

        // Strict MRU order: lowest recencyRank first
        list.sort(function(a, b) {
            return a.recencyRank - b.recencyRank;
        });

        windowsModel.clear();
        for (let i = 0; i < list.length; i++) {
            windowsModel.append(list[i]);
        }
    }

    // Public cycling API called by Main.qml switcherCycle
    function openWithDirection(dir) {
        refreshWindows();
        if (windowsModel.count <= 0) {
            root.selectedIndex = 0;
            return;
        }

        if (dir === "prev") {
            root.selectedIndex = windowsModel.count > 1 ? windowsModel.count - 1 : 0;
        } else {
            // Strictly start on the 2nd position (index 1) of the cycle
            root.selectedIndex = windowsModel.count > 1 ? 1 : 0;
        }
    }

    function cycleNext() {
        if (windowsModel.count <= 0) return;
        root.selectedIndex = (root.selectedIndex + 1) % windowsModel.count;
    }

    function cyclePrev() {
        if (windowsModel.count <= 0) return;
        root.selectedIndex = (root.selectedIndex - 1 + windowsModel.count) % windowsModel.count;
    }

    // Focus chosen window and close
    function activateSelected() {
        if (root.selectedIndex < 0 || root.selectedIndex >= windowsModel.count) {
            closeSwitcher();
            return;
        }
        let item = windowsModel.get(root.selectedIndex);
        if (!item || !item.address) {
            closeSwitcher();
            return;
        }

        let cmd = "hyprctl dispatch \"hl.dsp.focus({ window = 'address:" + item.address + "' })\"";
        if (item.isFloating) {
            cmd += " && hyprctl dispatch \"hl.dsp.window.alter_zorder({ mode = 'top' })\"";
        }
        Quickshell.execDetached(["bash", "-c", cmd]);
        closeSwitcher();
    }

    function closeSwitcher() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    Component.onCompleted: {
        refreshWindows();
    }

    Connections {
        target: root
        function onVisibleChanged() {
            if (root.visible) {
                root.forceActiveFocus();
            }
        }
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT (Horizontal Card Ribbon)
    // -------------------------------------------------------------------------
    Rectangle {
        id: panelBackground
        anchors.fill: parent
        radius: root.s(16)
        color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.85)
        border.color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.65)
        border.width: 1
        clip: true

        // Empty state when workspace has 0 windows
        Item {
            anchors.fill: parent
            visible: windowsModel.count === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: root.s(6)

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.isSpecialActive ? "Special Workspace Empty" : "Workspace Empty"
                    font.family: "SF Pro Text"
                    font.pixelSize: root.s(13)
                    font.weight: Font.SemiBold
                    color: root.subtext0
                }
            }
        }

        // Horizontal Card Row
        ListView {
            id: cardList
            anchors.fill: parent
            anchors.margins: root.containerPadding
            orientation: ListView.Horizontal
            spacing: root.cardGap
            model: windowsModel
            currentIndex: root.selectedIndex
            interactive: false
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                width: root.cardWidth
                height: root.cardHeight

                readonly property bool isSelected: index === root.selectedIndex

                Rectangle {
                    id: cardItem
                    anchors.fill: parent
                    radius: root.s(14)
                    color: isSelected ? root.cardSelectedBg : (cardHover.containsMouse ? Qt.rgba(0.18, 0.19, 0.23, 0.8) : root.cardBg)
                    border.color: isSelected ? root.cardBorderSelected : (cardHover.containsMouse ? Qt.rgba(0.4, 0.4, 0.5, 0.5) : root.cardBorderNormal)
                    border.width: isSelected ? 2 : 1

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(10)
                        spacing: root.s(6)

                        // App Icon
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: root.s(48)
                            Layout.preferredHeight: root.s(48)

                            Image {
                                anchors.centerIn: parent
                                width: root.s(44)
                                height: root.s(44)
                                source: model.icon.startsWith("/") ? "file://" + model.icon : "image://icon/" + model.icon
                                sourceSize: Qt.size(88, 88)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }
                        }

                        // App Name / Class
                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: model.className
                            font.family: "SF Pro Text"
                            font.pixelSize: root.s(12)
                            font.weight: isSelected ? Font.Bold : Font.DemiBold
                            color: isSelected ? root.text : root.subtext0
                            elide: Text.ElideRight
                        }

                        // Window Title
                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: model.title
                            font.family: "SF Pro Text"
                            font.pixelSize: root.s(10)
                            color: isSelected ? root.subtext1 : Qt.rgba(root.subtext0.r, root.subtext0.g, root.subtext0.b, 0.65)
                            elide: Text.ElideRight
                        }
                    }

                    // Floating indicator badge if floating (workspace number tag removed)
                    Rectangle {
                        visible: model.isFloating
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: root.s(6)
                        width: root.s(16)
                        height: root.s(16)
                        radius: root.s(8)
                        color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.8)

                        Text {
                            anchors.centerIn: parent
                            text: "F"
                            font.family: "SF Pro Text"
                            font.pixelSize: root.s(9)
                            font.weight: Font.Bold
                            color: root.text
                        }
                    }

                    MouseArea {
                        id: cardHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedIndex = index;
                            root.activateSelected();
                        }
                    }
                }
            }
        }
    }

    // Keyboard navigation
    Keys.onRightPressed: (event) => {
        cycleNext();
        event.accepted = true;
    }
    Keys.onLeftPressed: (event) => {
        cyclePrev();
        event.accepted = true;
    }
    Keys.onTabPressed: (event) => {
        if (event.modifiers & Qt.ShiftModifier) cyclePrev();
        else cycleNext();
        event.accepted = true;
    }
    Keys.onBacktabPressed: (event) => {
        cyclePrev();
        event.accepted = true;
    }
    Keys.onReturnPressed: (event) => {
        activateSelected();
        event.accepted = true;
    }
    Keys.onEnterPressed: (event) => {
        activateSelected();
        event.accepted = true;
    }
    Keys.onEscapePressed: (event) => {
        closeSwitcher();
        event.accepted = true;
    }
}
