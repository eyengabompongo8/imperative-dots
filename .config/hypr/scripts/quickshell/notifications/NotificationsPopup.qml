import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import QtCore
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    focus: true

    property var notifModel: NotificationService.history
    property var liveNotifs: NotificationService.liveNotifs
    property real layoutWidth
    property real layoutHeight

    // --- Responsive Scaling ---
    Scaler {
        id: scaler
        currentWidth: Screen.width
    }

    function s(val) {
        return scaler.s(val);
    }

    // --- Dynamic Sizing for Living Island / Right Panel ---
    readonly property real targetMasterWidth: window.s(400)
    readonly property real maxPanelHeight: window.s(760)

    readonly property real calculatedContentHeight: {
        let pad = window.s(32);
        let headerH = window.s(32);
        let spacing = window.s(12);
        if (!notifModel || notifModel.count === 0) {
            return window.s(180);
        }
        let listH = notifListView ? notifListView.contentHeight : 0;
        if (listH <= 0) {
            return window.s(760);
        }
        return pad + headerH + spacing + listH;
    }

    readonly property real targetMasterHeight: Math.max(window.s(160), Math.min(maxPanelHeight, calculatedContentHeight))

    // --- Dynamic Matugen Palette ---
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

    // --- DND State Tracking ---
    property bool dndEnabled: false
    Caching { id: paths }

    Process {
        id: dndPoller
        command: ["bash", "-c", "cat '" + paths.getCacheDir("dnd") + "/state' 2>/dev/null || echo '0'"]
        stdout: StdioCollector {
            onStreamFinished: window.dndEnabled = (this.text.trim() === "1")
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: dndPoller.running = true
    }

    function toggleDnd() {
        let newState = window.dndEnabled ? "0" : "1";
        window.dndEnabled = !window.dndEnabled;
        Quickshell.execDetached(["bash", "-c", "mkdir -p '" + paths.getCacheDir("dnd") + "' && echo '" + newState + "' > '" + paths.getCacheDir("dnd") + "/state'"]);
    }

    // --- Group Collapse State ---
    property var collapsedGroups: ({})

    function isCollapsed(groupName) {
        return !!collapsedGroups[groupName];
    }

    function toggleGroup(groupName) {
        let copy = Object.assign({}, collapsedGroups);
        copy[groupName] = !copy[groupName];
        collapsedGroups = copy;
    }

    function syncNotifCount() {
        NotificationService.updateNotifCountFile();
    }

    function clearGroup(appName) {
        NotificationService.clearGroup(appName);
    }

    function clearAllNotifs() {
        NotificationService.clearAllHistory();
    }

    function getGroupCount(appName) {
        return NotificationService.getGroupCount(appName);
    }

    // --- Window Focus Dispatcher ---
    function focusApp(appName, desktopEntry) {
        NotificationService.focusApp(appName, desktopEntry);
    }

    // --- Time Format Helper ---
    property double currentTime: Date.now()
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: window.currentTime = Date.now()
    }

    function formatTime(timestamp) {
        if (!timestamp) return "";
        let date = new Date(timestamp);
        let h = date.getHours().toString().padStart(2, '0');
        let m = date.getMinutes().toString().padStart(2, '0');
        let timeStr = h + ":" + m;

        let diffMs = window.currentTime - timestamp;
        let sec = Math.floor(diffMs / 1000);
        let relStr = "Just now";
        if (sec >= 60) {
            let min = Math.floor(sec / 60);
            if (min < 60) relStr = min + "m ago";
            else {
                let hrs = Math.floor(min / 60);
                if (hrs < 24) relStr = hrs + "h ago";
                else relStr = Math.floor(hrs / 24) + "d ago";
            }
        }
        return relStr + " • " + timeStr;
    }

    // Root Panel Container
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: window.s(16)
        border.width: 0
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: window.s(16)
            spacing: window.s(12)

            // --- HEADER ROW ---
            RowLayout {
                Layout.fillWidth: true
                spacing: window.s(8)

                Text {
                    text: "NOTIFICATIONS"
                    font.family: "SF Pro Text"
                    font.weight: Font.Black
                    font.pixelSize: window.s(14)
                    color: window.text
                }

                // Unread Count Badge
                Rectangle {
                    visible: notifModel && notifModel.count > 0
                    Layout.preferredHeight: window.s(18)
                    Layout.preferredWidth: Math.max(window.s(18), countText.implicitWidth + window.s(10))
                    radius: height / 2
                    color: window.mauve

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: notifModel ? notifModel.count : "0"
                        font.family: "SF Pro Text"
                        font.weight: Font.Bold
                        font.pixelSize: window.s(10)
                        color: window.crust
                    }
                }

                Item { Layout.fillWidth: true }

                // DND Toggle Button
                Rectangle {
                    Layout.preferredWidth: window.s(32)
                    Layout.preferredHeight: window.s(32)
                    radius: window.s(16)
                    color: window.dndEnabled ? window.mauve : (dndMa.containsMouse ? window.surface2 : window.surface1)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        font.family: "SF Pro "
                        font.pixelSize: window.s(16)
                        color: window.dndEnabled ? window.crust : (window.dndEnabled ? window.mauve : window.subtext0)
                        text: window.dndEnabled ? "󰂛" : "󰂚"
                    }

                    MouseArea {
                        id: dndMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.toggleDnd()
                    }
                }

                // Clear All Button
                Rectangle {
                    visible: notifModel && notifModel.count > 0
                    Layout.preferredWidth: window.s(32)
                    Layout.preferredHeight: window.s(32)
                    radius: window.s(16)
                    color: clearAllMa.containsMouse ? Qt.alpha(window.red, 0.2) : window.surface1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        font.family: "SF Pro "
                        font.pixelSize: window.s(15)
                        color: clearAllMa.containsMouse ? window.red : window.subtext0
                        text: "󰅖"
                    }

                    MouseArea {
                        id: clearAllMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.clearAllNotifs()
                    }
                }
            }

            // --- EMPTY STATE ---
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !notifModel || notifModel.count === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: window.s(10)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        font.family: "SF Pro "
                        font.pixelSize: window.s(48)
                        color: window.overlay0
                        text: "󰂜"
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        font.family: "SF Pro Text"
                        font.weight: Font.Medium
                        font.pixelSize: window.s(13)
                        color: window.subtext0
                        text: "No notifications right now"
                    }
                }
            }

            // --- NOTIFICATION LIST VIEW ---
            ListView {
                id: notifListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: notifModel && notifModel.count > 0
                model: window.notifModel
                spacing: 0
                interactive: contentHeight > height
                clip: true

                ScrollBar.vertical: ScrollBar {
                    active: notifListView.moving || notifListView.movingVertically
                    width: window.s(4)
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: window.s(4); radius: window.s(2); color: window.surface2 }
                }

                // Fluid Add / Remove Transitions
                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 250; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 250; easing.type: Easing.OutBack }
                    }
                }
                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InCubic }
                        NumberAnimation { property: "scale"; to: 0.9; duration: 200; easing.type: Easing.InCubic }
                    }
                }
                displaced: Transition {
                    NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutCubic }
                }

                // --- App Grouping Header ---
                section.property: "appName"
                section.criteria: ViewSection.FullString
                section.delegate: Item {
                    width: ListView.view.width
                    height: window.s(36)

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: window.s(4)
                        anchors.bottomMargin: window.s(2)
                        color: groupHeaderMa.containsMouse ? window.surface1 : "transparent"
                        radius: window.s(6)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: window.s(6)
                            anchors.rightMargin: window.s(6)
                            spacing: window.s(6)

                            MouseArea {
                                id: groupHeaderMa
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.toggleGroup(section)

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: window.s(6)

                                    Text {
                                        font.family: "SF Pro "
                                        font.pixelSize: window.s(12)
                                        color: window.mauve
                                        text: window.isCollapsed(section) ? "󰅂" : "󰅀"
                                    }

                                    Text {
                                        text: section.toUpperCase()
                                        font.family: "SF Pro Text"
                                        font.weight: Font.Black
                                        font.pixelSize: window.s(11)
                                        color: window.subtext0
                                    }

                                    // Group count badge
                                    Rectangle {
                                        property int grpCount: {
                                            let _d = window.notifModel ? window.notifModel.count : 0;
                                            return window.getGroupCount(section);
                                        }
                                        visible: grpCount > 0
                                        Layout.preferredHeight: window.s(16)
                                        Layout.preferredWidth: Math.max(window.s(16), grpCountText.implicitWidth + window.s(8))
                                        radius: height / 2
                                        color: window.surface2

                                        Text {
                                            id: grpCountText
                                            anchors.centerIn: parent
                                            text: parent.grpCount
                                            font.family: "SF Pro Text"
                                            font.weight: Font.Bold
                                            font.pixelSize: window.s(9)
                                            color: window.subtext0
                                        }
                                    }

                                    Item { Layout.fillWidth: true }
                                }
                            }

                            // Group Clear Button
                            Rectangle {
                                Layout.preferredWidth: window.s(22)
                                Layout.preferredHeight: window.s(22)
                                radius: window.s(11)
                                color: grpClearMa.containsMouse ? Qt.alpha(window.red, 0.2) : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    font.family: "SF Pro "
                                    font.pixelSize: window.s(11)
                                    color: grpClearMa.containsMouse ? window.red : window.overlay0
                                    text: "󰅖"
                                }

                                MouseArea {
                                    id: grpClearMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.clearGroup(section)
                                }
                            }
                        }
                    }
                }

                // --- Individual Notification Card Delegate ---
                delegate: Item {
                    id: delegateWrapper
                    width: ListView.view.width
                    property bool isHidden: window.isCollapsed(model.appName)
                    height: isHidden ? 0 : cardRect.height + window.s(8)
                    visible: height > 0
                    opacity: isHidden ? 0 : 1
                    clip: true

                    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    property var realNotif: window.liveNotifs ? window.liveNotifs[model.uid] : null

                    function removeThisNotif() {
                        NotificationService.removeHistory(model.uid);
                    }

                    property var actionArray: {
                        try {
                            return model.actionsJson ? JSON.parse(model.actionsJson) : [];
                        } catch (e) {
                            return [];
                        }
                    }

                    Rectangle {
                        id: cardRect
                        anchors.top: parent.top
                        width: parent.width
                        height: colLayout.height + window.s(20)
                        radius: window.s(12)
                        color: cardMa.containsMouse ? window.surface2 : window.surface1
                        border.color: model.urgency === 2 ? window.red : (cardMa.containsMouse ? Qt.rgba(window.text.r, window.text.g, window.text.b, 0.25) : Qt.rgba(window.text.r, window.text.g, window.text.b, 0.12))
                        border.width: 1
                        clip: true

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        // Main Card Interaction (Click & Middle Click)
                        MouseArea {
                            id: cardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.MiddleButton) {
                                    delegateWrapper.removeThisNotif();
                                    return;
                                }

                                // Left click: invoke default action if present
                                if (delegateWrapper.realNotif && delegateWrapper.realNotif.actions) {
                                    for (var i = 0; i < delegateWrapper.realNotif.actions.length; i++) {
                                        if (delegateWrapper.realNotif.actions[i].identifier === "default") {
                                            delegateWrapper.realNotif.actions[i].invoke();
                                            break;
                                        }
                                    }
                                }

                                window.focusApp(model.appName, model.desktopEntry);
                                delegateWrapper.removeThisNotif();
                            }
                        }

                        ColumnLayout {
                            id: colLayout
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: window.s(10)
                            anchors.leftMargin: window.s(10)
                            spacing: window.s(4)

                            // Header Line: Icon, AppName, Timestamp, Dismiss
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: window.s(6)

                                Image {
                                    visible: model.iconPath !== ""
                                    source: model.iconPath ? (model.iconPath.startsWith("/") ? "file://" + model.iconPath : "image://icon/" + model.iconPath) : ""
                                    Layout.preferredWidth: window.s(16)
                                    Layout.preferredHeight: window.s(16)
                                    fillMode: Image.PreserveAspectFit
                                }

                                Text {
                                    text: model.appName || "System"
                                    font.family: "SF Pro Text"
                                    font.weight: Font.Bold
                                    font.pixelSize: window.s(11)
                                    color: window.subtext0
                                }

                                Text {
                                    text: "• " + window.formatTime(model.timestamp)
                                    font.family: "SF Pro Text"
                                    font.pixelSize: window.s(10)
                                    color: window.overlay0
                                    visible: model.timestamp !== undefined && model.timestamp > 0
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    Layout.preferredWidth: window.s(20)
                                    Layout.preferredHeight: window.s(20)
                                    radius: window.s(10)
                                    color: itemDismissMa.containsMouse ? Qt.alpha(window.red, 0.2) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        font.family: "SF Pro "
                                        font.pixelSize: window.s(10)
                                        color: itemDismissMa.containsMouse ? window.red : window.overlay0
                                        text: "󰅖"
                                    }

                                    MouseArea {
                                        id: itemDismissMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: delegateWrapper.removeThisNotif()
                                    }
                                }
                            }

                            // Summary Title
                            Text {
                                text: model.summary || "Notification"
                                font.family: "SF Pro Text"
                                font.weight: Font.Bold
                                font.pixelSize: window.s(12)
                                color: window.text
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                textFormat: Text.StyledText
                            }

                            // Body Text with Hyperlink support
                            Text {
                                text: model.body || ""
                                font.family: "SF Pro Text"
                                font.weight: Font.Medium
                                font.pixelSize: window.s(11)
                                color: window.subtext0
                                linkColor: window.blue
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                visible: text !== ""
                                textFormat: Text.StyledText
                                onLinkActivated: (link) => Quickshell.execDetached(["xdg-open", link])
                            }

                            // Optional Image Preview Thumbnail
                            Image {
                                id: previewImg
                                visible: source !== "" && status === Image.Ready
                                source: {
                                    if (!model.imagePath) return "";
                                    var p = model.imagePath;
                                    if (p.startsWith("/") || p.startsWith("file://") || p.startsWith("http://") || p.startsWith("https://")) {
                                        return p.startsWith("/") ? "file://" + p : p;
                                    }
                                    return "";
                                }
                                Layout.fillWidth: true
                                Layout.preferredHeight: visible ? window.s(120) : 0
                                fillMode: Image.PreserveAspectCrop
                                clip: true
                            }

                            // Action Buttons Dock (Flow layout for > 2 actions)
                            Flow {
                                Layout.fillWidth: true
                                Layout.topMargin: delegateWrapper.actionArray.length > 0 ? window.s(4) : 0
                                spacing: window.s(6)
                                visible: delegateWrapper.actionArray.length > 0

                                Repeater {
                                    model: delegateWrapper.actionArray
                                    delegate: Rectangle {
                                        width: Math.min(implicitBtnWidth, cardRect.width - window.s(28))
                                        height: window.s(26)
                                        radius: window.s(6)

                                        property real implicitBtnWidth: btnText.implicitWidth + window.s(16)
                                        property bool isPrimary: index === 0

                                        color: isPrimary ? (btnMa.containsMouse ? window.blue : Qt.darker(window.blue, 1.2)) : (btnMa.containsMouse ? window.surface2 : window.surface0)
                                        border.color: isPrimary ? window.blue : window.surface2
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Text {
                                            id: btnText
                                            anchors.centerIn: parent
                                            text: modelData.text || "Action"
                                            font.family: "SF Pro Text"
                                            font.weight: Font.Bold
                                            font.pixelSize: window.s(10)
                                            color: isPrimary ? window.crust : window.text
                                            elide: Text.ElideRight
                                            width: parent.width - window.s(8)
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        MouseArea {
                                            id: btnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: {
                                                NotificationService.invokeAction(model.uid, modelData.id || modelData.identifier);
                                                NotificationService.focusApp(model.appName, model.desktopEntry);
                                                NotificationService.removeHistory(model.uid);
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
