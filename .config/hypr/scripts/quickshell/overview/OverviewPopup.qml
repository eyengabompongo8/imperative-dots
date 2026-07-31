import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

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
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color mauve: _theme.mauve || "#cba6f7"
    readonly property color red: _theme.red || "#f38ba8"
    readonly property color green: _theme.green || "#a6e3a1"
    readonly property color blue: _theme.blue || "#89b4fa"
    readonly property color yellow: _theme.yellow || "#f9e2af"

    property int workspaceCount: 8
    property int activeWorkspaceId: 1
    property real monWidth: 1920
    property real monHeight: 1080
    property var workspacesData: []

    // Drag & Drop State Tracking
    property string draggedWindowAddress: ""
    property int draggedFromWs: 0
    property bool isDragging: false
    property bool isOverTrash: false

    function fetchOverviewData() {
        if (!overviewFetcher.running) {
            overviewFetcher.running = true;
        }
    }

    Process {
        id: overviewFetcher
        running: false
        command: ["bash", "-c", "python3 " + Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/overview/overview_fetcher.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) {
                        let parsed = JSON.parse(this.text);
                        window.workspaceCount = parsed.workspaceCount || 8;
                        window.activeWorkspaceId = parsed.activeWorkspaceId || 1;
                        if (parsed.monitor) {
                            window.monWidth = parsed.monitor.width || 1920;
                            window.monHeight = parsed.monitor.height || 1080;
                        }
                        window.workspacesData = parsed.workspaces || [];
                    }
                } catch(e) {
                    console.log("Error parsing overview data: ", e);
                }
            }
        }
    }

    Timer {
        id: autoRefreshTimer
        interval: 1000
        repeat: true
        running: window.visible && !window.isDragging
        onTriggered: window.fetchOverviewData()
    }

    Connections {
        target: window
        function onVisibleChanged() {
            if (window.visible) {
                window.fetchOverviewData();
                introPhaseAnim.restart();
            }
        }
    }

    // -------------------------------------------------------------------------
    // HYPRLAND LUA DISPATCH ACTIONS
    // -------------------------------------------------------------------------
    function focusWorkspace(wsId) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + wsId.toString() + " })"]);
        closeOverview();
    }

    function focusWindow(address) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = 'address:" + address + "' })"]);
        closeOverview();
    }

    function closeWindow(address) {
        Quickshell.execDetached(["bash", "-c", "hyprctl dispatch \"hl.dsp.focus({ window = 'address:" + address + "' })\" && hyprctl dispatch \"hl.dsp.window.close()\""]);
        Qt.callLater(() => window.fetchOverviewData());
    }

    function moveWindowToWorkspace(address, targetWsId) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = " + targetWsId.toString() + ", window = 'address:" + address + "' })"]);
        Qt.callLater(() => window.fetchOverviewData());
    }

    function closeOverview() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    Keys.onEscapePressed: {
        closeOverview();
        event.accepted = true;
    }

    property real introPhase: 0
    NumberAnimation on introPhase {
        id: introPhaseAnim
        from: 0; to: 1; duration: 250; easing.type: Easing.OutExpo; running: true
    }

    Rectangle {
        id: mainCard
        anchors.fill: parent
        radius: window.s(16)
        color: Qt.rgba(window.base.r, window.base.g, window.base.b, 0.82)
        border.color: window.surface1
        border.width: 1
        clip: true

        opacity: window.introPhase

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: window.s(10)
            spacing: window.s(8)

            // WORKSPACE GRID (4 Cols x 2 Rows)
            GridLayout {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 4
                rowSpacing: window.s(8)
                columnSpacing: window.s(8)

                Repeater {
                    model: window.workspacesData

                    delegate: Rectangle {
                        id: wsCard
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        readonly property int wsId: modelData.id
                        readonly property bool isActive: modelData.isActive
                        readonly property bool isOccupied: modelData.isOccupied
                        readonly property var windowsList: modelData.windows || []
                        property bool isHoveredDrop: false

                        // Elevate source workspace z-index when dragging so dragged window floats ABOVE all other workspace cards!
                        z: (window.draggedFromWs === wsId) ? 9999 : 1

                        radius: window.s(12)
                        color: isHoveredDrop ? Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.65) 
                                             : (wsCardMa.containsMouse ? Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.55) 
                                                                       : Qt.rgba(window.mantle.r, window.mantle.g, window.mantle.b, 0.25))
                        border.color: isHoveredDrop ? window.green : (isActive ? window.mauve : (wsCardMa.containsMouse ? window.surface2 : Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.3)))
                        border.width: (isActive || isHoveredDrop) ? 2 : 1

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        // Background MouseArea for workspace selection
                        MouseArea {
                            id: wsCardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.focusWorkspace(wsCard.wsId);
                            }
                        }

                        // DropArea for receiving window drops
                        DropArea {
                            anchors.fill: parent
                            keys: ["window-card"]

                            onEntered: (drag) => {
                                wsCard.isHoveredDrop = true;
                            }

                            onExited: {
                                wsCard.isHoveredDrop = false;
                            }

                            onDropped: (drop) => {
                                wsCard.isHoveredDrop = false;
                                let addr = window.draggedWindowAddress;
                                if (addr !== "" && wsCard.wsId !== window.draggedFromWs) {
                                    window.moveWindowToWorkspace(addr, wsCard.wsId);
                                    drop.accept();
                                }
                            }
                        }

                        // Background Workspace Number Display
                        Text {
                            anchors.centerIn: parent
                            text: wsCard.wsId.toString()
                            font.family: "SF Pro Display"
                            font.pixelSize: window.s(60)
                            font.weight: Font.Black
                            color: wsCard.isActive ? window.mauve : window.text
                            opacity: wsCard.isActive ? 0.25 : 0.08
                            z: 0
                        }

                        // MONITOR VIEWPORT
                        Rectangle {
                            id: viewport
                            anchors.fill: parent
                            anchors.margins: window.s(4)
                            radius: window.s(8)
                            color: "transparent"
                            clip: !window.isDragging
                            z: 1

                            Repeater {
                                model: wsCard.windowsList

                                delegate: Item {
                                    id: winContainer

                                    readonly property var winData: modelData
                                    readonly property real scaleX: viewport.width / window.monWidth
                                    readonly property real scaleY: viewport.height / window.monHeight

                                    readonly property real origX: winData.at ? (winData.at[0] * scaleX) : 0
                                    readonly property real origY: winData.at ? (winData.at[1] * scaleY) : 0
                                    readonly property real origW: winData.size ? Math.max(window.s(65), winData.size[0] * scaleX) : window.s(65)
                                    readonly property real origH: winData.size ? Math.max(window.s(48), winData.size[1] * scaleY) : window.s(48)

                                    x: origX
                                    y: origY
                                    width: Math.min(origW, viewport.width - origX)
                                    height: Math.min(origH, viewport.height - origY)

                                    // Floating windows ALWAYS sit on top (z: 100 for floating, z: 1 for tiling) so they can be grabbed without conflict!
                                    z: winData.floating ? 100 : 1

                                    Drag.active: winDragArea.drag.active
                                    Drag.keys: ["window-card"]

                                    Rectangle {
                                        id: winMiniCard
                                        anchors.fill: parent
                                        radius: window.s(6)
                                        color: winDragArea.containsMouse ? Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.9) 
                                                                         : (winData.floating ? Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.8) 
                                                                                             : Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.7))
                                        border.color: winDragArea.containsMouse ? window.mauve : (winData.floating ? window.yellow : window.surface2)
                                        border.width: (winDragArea.containsMouse || winData.floating) ? 2 : 1
                                        clip: true

                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        Behavior on border.color { ColorAnimation { duration: 120 } }

                                        // Centered Column Layout with Larger Logo on top & Title below
                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            width: parent.width - window.s(4)
                                            spacing: window.s(2)

                                            Image {
                                                Layout.alignment: Qt.AlignHCenter
                                                Layout.preferredWidth: Math.min(winMiniCard.width * 0.45, window.s(36))
                                                Layout.preferredHeight: Math.min(winMiniCard.height * 0.45, window.s(36))
                                                source: winData.icon.startsWith("/") ? "file://" + winData.icon : "image://icon/" + winData.icon
                                                sourceSize: Qt.size(64, 64)
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                smooth: true
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignHCenter
                                                text: winData.title
                                                horizontalAlignment: Text.AlignHCenter
                                                font.family: "SF Pro Text"
                                                font.pixelSize: window.s(9)
                                                font.weight: Font.DemiBold
                                                color: window.text
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            id: winDragArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            drag.target: winContainer
                                            drag.axis: Drag.XAndYAxis

                                            onPressed: (mouse) => {
                                                // Unbind x and y explicitly so drag.target moves winContainer without QML binding conflict
                                                winContainer.x = winContainer.x;
                                                winContainer.y = winContainer.y;
                                                winContainer.z = 9999;

                                                window.draggedWindowAddress = winData.address;
                                                window.draggedFromWs = wsCard.wsId;
                                                window.isDragging = true;
                                                winContainer.Drag.hotSpot.x = winContainer.width / 2;
                                                winContainer.Drag.hotSpot.y = winContainer.height / 2;
                                            }

                                            onReleased: (mouse) => {
                                                if (winContainer.Drag.active) {
                                                    winContainer.Drag.drop();
                                                }
                                                window.draggedWindowAddress = "";
                                                window.draggedFromWs = 0;
                                                window.isDragging = false;

                                                // Re-bind x, y, and z upon release
                                                winContainer.x = Qt.binding(function() { return winContainer.origX; });
                                                winContainer.y = Qt.binding(function() { return winContainer.origY; });
                                                winContainer.z = Qt.binding(function() { return winData.floating ? 100 : 1; });
                                            }

                                            onClicked: (mouse) => {
                                                window.focusWindow(winData.address);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // TRASHCAN DROP ZONE FOR CLOSING WINDOWS
            // -----------------------------------------------------------------
            Rectangle {
                id: trashZone
                Layout.fillWidth: true
                Layout.preferredHeight: window.s(36)
                radius: window.s(10)
                color: window.isOverTrash ? window.red : Qt.rgba(window.mantle.r, window.mantle.g, window.mantle.b, 0.3)
                border.color: window.isOverTrash ? window.red : Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.4)
                border.width: window.isOverTrash ? 2 : 1

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                DropArea {
                    anchors.fill: parent
                    keys: ["window-card"]

                    onEntered: (drag) => {
                        window.isOverTrash = true;
                    }

                    onExited: {
                        window.isOverTrash = false;
                    }

                    onDropped: (drop) => {
                        window.isOverTrash = false;
                        let addr = window.draggedWindowAddress;
                        if (addr !== "") {
                            window.closeWindow(addr);
                            drop.accept();
                        }
                    }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: window.s(6)

                    Text {
                        text: "🗑️"
                        font.pixelSize: window.s(14)
                    }

                    Text {
                        text: window.isOverTrash ? "Release to Close Window" : "Drag window here to close"
                        font.family: "SF Pro Text"
                        font.pixelSize: window.s(11)
                        font.weight: window.isOverTrash ? Font.Bold : Font.Medium
                        color: window.isOverTrash ? window.crust : window.subtext0
                    }
                }
            }
        }
    }
}
