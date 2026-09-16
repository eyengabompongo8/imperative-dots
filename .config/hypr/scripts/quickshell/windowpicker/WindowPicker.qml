import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"
import "FuzzySearch.js" as Fuzzy

Item {
    id: window
    focus: true

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }

    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color subtext1: _theme.subtext1 || "#a6adc8"
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color overlay0: _theme.overlay0 || "#6c7086"
    readonly property color mauve: _theme.mauve || "#cba6f7"
    readonly property color blue: _theme.blue || "#89b4fa"

    // -------------------------------------------------------------------------
    // STATE & DATA
    // -------------------------------------------------------------------------
    property var allWindows: []
    property int currentActiveWsId: 1

    ListModel {
        id: filteredModel
    }

    // Icon overrides & class map
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

    // --- FETCH WINDOWS FROM HYPRLAND ---
    function refreshWindows() {
        if (typeof Hyprland === "undefined") return;

        let activeWs = 1;
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id) {
            activeWs = Hyprland.focusedWorkspace.id;
        } else if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace && Hyprland.focusedMonitor.activeWorkspace.id) {
            activeWs = Hyprland.focusedMonitor.activeWorkspace.id;
        }
        window.currentActiveWsId = activeWs;

        let toplevels = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        let list = [];

        for (let i = 0; i < toplevels.length; i++) {
            let t = toplevels[i];
            if (!t) continue;
            let ipc = t.lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true) continue;

            let wsId = (t.workspace && t.workspace.id !== undefined) ? t.workspace.id : (ipc.workspace ? ipc.workspace.id : 1);
            let wsName = (t.workspace && t.workspace.name) ? t.workspace.name : (ipc.workspace ? ipc.workspace.name : wsId.toString());

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

            list.push({
                address: addr,
                className: cls,
                title: title,
                icon: icon,
                workspaceId: wsId,
                workspaceName: wsName,
                isCurrentWs: (wsId === activeWs),
                focusHistory: focusHistory
            });
        }

        list.sort(function(a, b) {
            return a.focusHistory - b.focusHistory;
        });

        window.allWindows = list;
        filterWindows(searchInput.text);
    }

    // --- FILTERING & SCORING ---
    function filterWindows(query) {
        let q = (query || "").trim();
        let scored = [];
        let highlightColor = window.mauve.toString();

        for (let i = 0; i < window.allWindows.length; i++) {
            let win = window.allWindows[i];
            let res = Fuzzy.scoreWindow(q, win, i);
            if (res.matched) {
                let dispClass = Fuzzy.highlightText(win.className, res.classIndices, highlightColor);
                let dispTitle = Fuzzy.highlightText(win.title, res.titleIndices, highlightColor);

                scored.push({
                    item: win,
                    score: res.score,
                    displayClass: dispClass,
                    displayTitle: dispTitle
                });
            }
        }

        scored.sort(function(a, b) {
            return b.score - a.score;
        });

        filteredModel.clear();
        for (let i = 0; i < scored.length; i++) {
            let s = scored[i];
            filteredModel.append({
                address: s.item.address,
                className: s.item.className,
                title: s.item.title,
                displayClass: s.displayClass,
                displayTitle: s.displayTitle,
                icon: s.item.icon,
                workspaceId: s.item.workspaceId,
                workspaceName: s.item.workspaceName,
                isCurrentWs: s.item.isCurrentWs
            });
        }

        if (filteredModel.count > 0) {
            windowList.currentIndex = 0;
        } else {
            windowList.currentIndex = -1;
        }
    }

    // --- FOCUS WINDOW ACTION ---
    function focusSelectedWindow() {
        if (windowList.currentIndex < 0 || windowList.currentIndex >= filteredModel.count) return;
        let item = filteredModel.get(windowList.currentIndex);
        if (!item || !item.address) return;

        Quickshell.execDetached(["bash", "-c", "hyprctl dispatch \"hl.dsp.focus({ window = 'address:" + item.address + "' })\""]);
        closePicker();
    }

    function closePicker() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    // --- EVENT HOOKS ---
    Connections {
        target: Hyprland || null
        function onRawEvent(event) {
            if (!event || !window.visible) return;
            let ev = event.name;
            if (ev === "openwindow" || ev === "closewindow" || ev === "movewindow" || ev === "changefloatingmode") {
                window.refreshWindows();
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        running: true
        repeat: false
        onTriggered: {
            searchInput.forceActiveFocus();
        }
    }

    Component.onCompleted: {
        window.refreshWindows();
        focusTimer.restart();
    }

    Connections {
        target: window
        function onVisibleChanged() {
            if (window.visible) {
                searchInput.text = "";
                window.refreshWindows();
                focusTimer.restart();
            }
        }
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Rectangle {
        id: mainCard
        anchors.fill: parent
        radius: window.s(16)
        color: window.base
        border.color: window.surface1
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // =================================================================
            // 1. SEARCH HEADER
            // =================================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: window.s(60)
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: window.s(20)
                    anchors.rightMargin: window.s(20)
                    spacing: window.s(14)

                    // Search Icon
                    Text {
                        text: ""
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: window.s(16)
                        color: searchInput.activeFocus ? window.mauve : window.subtext0
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        background: Item {}
                        color: window.text
                        font.family: "SF Pro Display"
                        font.pixelSize: window.s(16)
                        placeholderText: "Search windows..."
                        placeholderTextColor: window.subtext0
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true

                        onTextChanged: window.filterWindows(text)

                        Keys.onDownPressed: {
                            if (windowList.currentIndex < filteredModel.count - 1) {
                                windowList.currentIndex++;
                            }
                            event.accepted = true;
                        }
                        Keys.onUpPressed: {
                            if (windowList.currentIndex > 0) {
                                windowList.currentIndex--;
                            }
                            event.accepted = true;
                        }
                        Keys.onReturnPressed: {
                            window.focusSelectedWindow();
                            event.accepted = true;
                        }
                        Keys.onEnterPressed: {
                            window.focusSelectedWindow();
                            event.accepted = true;
                        }
                        Keys.onEscapePressed: {
                            window.closePicker();
                            event.accepted = true;
                        }

                        Keys.onPressed: (event) => {
                            // Ctrl + J / Ctrl + N (Down)
                            if (event.modifiers & Qt.ControlModifier && (event.key === Qt.Key_J || event.key === Qt.Key_N)) {
                                if (windowList.currentIndex < filteredModel.count - 1) windowList.currentIndex++;
                                event.accepted = true;
                            }
                            // Ctrl + K / Ctrl + P (Up)
                            else if (event.modifiers & Qt.ControlModifier && (event.key === Qt.Key_K || event.key === Qt.Key_P)) {
                                if (windowList.currentIndex > 0) windowList.currentIndex--;
                                event.accepted = true;
                            }
                        }
                    }

                    // Matches Count Badge
                    Rectangle {
                        Layout.preferredHeight: window.s(26)
                        Layout.preferredWidth: countText.implicitWidth + window.s(16)
                        radius: window.s(6)
                        color: window.surface0
                        border.color: window.surface1
                        border.width: 1

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: (windowList.currentIndex >= 0 ? (windowList.currentIndex + 1) : 0) + " / " + filteredModel.count
                            font.family: "SF Pro Text"
                            font.pixelSize: window.s(12)
                            font.weight: Font.DemiBold
                            color: filteredModel.count > 0 ? window.mauve : window.overlay0
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.5)
            }

            // =================================================================
            // 2. RESULTS LIST
            // =================================================================
            ListView {
                id: windowList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: window.s(8)
                model: filteredModel
                spacing: window.s(4)
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        positionViewAtIndex(currentIndex, ListView.Contain);
                    }
                }

                delegate: Item {
                    id: rowDelegate
                    width: windowList.width
                    height: window.s(56)

                    readonly property bool isCurrent: index === windowList.currentIndex

                    Rectangle {
                        anchors.fill: parent
                        radius: window.s(10)
                        color: isCurrent ? Qt.rgba(window.mauve.r, window.mauve.g, window.mauve.b, 0.16)
                                         : (rowMa.containsMouse ? Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.4) : "transparent")
                        border.color: isCurrent ? Qt.rgba(window.mauve.r, window.mauve.g, window.mauve.b, 0.6) : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: window.s(12)
                            anchors.rightMargin: window.s(14)
                            spacing: window.s(14)

                            // App Icon Container
                            Rectangle {
                                Layout.preferredWidth: window.s(38)
                                Layout.preferredHeight: window.s(38)
                                radius: window.s(10)
                                color: isCurrent ? Qt.rgba(window.mauve.r, window.mauve.g, window.mauve.b, 0.22) : window.surface0

                                Image {
                                    anchors.centerIn: parent
                                    width: window.s(24)
                                    height: window.s(24)
                                    source: model.icon.startsWith("/") ? "file://" + model.icon : "image://icon/" + model.icon
                                    sourceSize: Qt.size(48, 48)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                }
                            }

                            // Class Name & Title
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: window.s(2)

                                Text {
                                    Layout.fillWidth: true
                                    text: model.displayClass
                                    textFormat: Text.RichText
                                    font.family: "SF Pro Text"
                                    font.pixelSize: window.s(14)
                                    font.weight: isCurrent ? Font.Bold : Font.DemiBold
                                    color: isCurrent ? window.mauve : window.text
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: model.displayTitle
                                    textFormat: Text.RichText
                                    font.family: "SF Pro Text"
                                    font.pixelSize: window.s(12)
                                    color: isCurrent ? window.subtext1 : window.subtext0
                                    elide: Text.ElideRight
                                }
                            }

                            // Workspace Badge
                            Rectangle {
                                Layout.preferredHeight: window.s(24)
                                Layout.preferredWidth: wsBadgeText.implicitWidth + window.s(14)
                                radius: window.s(6)
                                color: model.isCurrentWs ? Qt.rgba(window.blue.r, window.blue.g, window.blue.b, 0.22)
                                                         : Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.5)
                                border.color: model.isCurrentWs ? Qt.rgba(window.blue.r, window.blue.g, window.blue.b, 0.6) : "transparent"
                                border.width: 1

                                Text {
                                    id: wsBadgeText
                                    anchors.centerIn: parent
                                    text: "WS " + model.workspaceId
                                    font.family: "SF Pro Text"
                                    font.pixelSize: window.s(12)
                                    font.weight: Font.DemiBold
                                    color: model.isCurrentWs ? window.blue : window.subtext0
                                }
                            }
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                windowList.currentIndex = index;
                                window.focusSelectedWindow();
                            }
                        }
                    }
                }

                // Empty State
                Item {
                    anchors.centerIn: parent
                    visible: filteredModel.count === 0
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: window.s(8)
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "No matching windows"
                            font.family: "SF Pro Text"
                            font.pixelSize: window.s(14)
                            font.weight: Font.Medium
                            color: window.overlay0
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.5)
            }

            // =================================================================
            // 3. FOOTER
            // =================================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: window.s(36)
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: window.s(18)
                    anchors.rightMargin: window.s(18)
                    spacing: window.s(16)

                    RowLayout {
                        spacing: window.s(5)
                        Text { text: "↵"; font.family: "SF Pro Text"; font.pixelSize: window.s(12); font.weight: Font.Bold; color: window.mauve }
                        Text { text: "Focus"; font.family: "SF Pro Text"; font.pixelSize: window.s(12); color: window.subtext0 }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: window.s(5)
                        Text { text: "↑↓ / ^J ^K"; font.family: "SF Pro Text"; font.pixelSize: window.s(12); font.weight: Font.Medium; color: window.overlay0 }
                        Text { text: "Navigate"; font.family: "SF Pro Text"; font.pixelSize: window.s(12); color: window.overlay0 }
                    }

                    RowLayout {
                        spacing: window.s(5)
                        Text { text: "Esc"; font.family: "SF Pro Text"; font.pixelSize: window.s(12); font.weight: Font.Medium; color: window.overlay0 }
                        Text { text: "Close"; font.family: "SF Pro Text"; font.pixelSize: window.s(12); color: window.overlay0 }
                    }
                }
            }
        }
    }
}
