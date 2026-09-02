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

    // --- Group Collapse & Grouping State ---
    readonly property bool groupByApp: NotificationService.groupByApp
    property var collapsedGroups: ({})
    property var viewedUids: ({})

    function isCollapsed(groupName) {
        return !!collapsedGroups[groupName];
    }

    function recordExpandedGroupsAsViewed() {
        if (!window.notifModel) return;
        let copy = Object.assign({}, viewedUids);
        for (let i = 0; i < window.notifModel.count; i++) {
            let item = window.notifModel.get(i);
            if (item && (!window.groupByApp || !window.isCollapsed(item.appName))) {
                copy[item.uid] = true;
            }
        }
        viewedUids = copy;
    }

    Connections {
        target: NotificationService
        function onInPlaceNotificationReceived(uid, appName) {
            if (window.isCollapsed(appName)) {
                let copy = Object.assign({}, window.collapsedGroups);
                copy[appName] = false;
                window.collapsedGroups = copy;
            }
            window.recordExpandedGroupsAsViewed();
            if (notifListView) {
                notifListView.smoothScrollToTop();
            }
        }
    }

    property bool isInitialLoadComplete: false
    Timer {
        id: initLoadTimer
        interval: 120
        running: true
        repeat: false
        onTriggered: window.isInitialLoadComplete = true
    }

    Component.onCompleted: {
        recordExpandedGroupsAsViewed();
    }

    Component.onDestruction: {
        for (let uid in viewedUids) {
            NotificationService.markAsSeen(parseInt(uid));
        }
    }

    function toggleGroup(groupName) {
        let copy = Object.assign({}, collapsedGroups);
        let willBeExpanded = !!copy[groupName];
        copy[groupName] = !copy[groupName];
        collapsedGroups = copy;
        if (willBeExpanded) {
            recordExpandedGroupsAsViewed();
        }
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
    function focusApp(appName, desktopEntry, senderPid, summary) {
        NotificationService.focusApp(appName, desktopEntry, senderPid, summary);
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

                // Total Notifications Badge (Highlighted when has unread)
                Rectangle {
                    property bool hasUnread: NotificationService.unseenCount > 0
                    visible: notifModel && notifModel.count > 0
                    Layout.preferredHeight: window.s(18)
                    Layout.preferredWidth: Math.max(window.s(18), countText.implicitWidth + window.s(10))
                    radius: height / 2
                    color: hasUnread ? window.mauve : window.surface2
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: notifModel ? notifModel.count : "0"
                        font.family: "SF Pro Text"
                        font.weight: Font.Bold
                        font.pixelSize: window.s(10)
                        color: parent.hasUnread ? window.crust : window.subtext0
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                Item { Layout.fillWidth: true }

                // Group by App Toggle Button
                Rectangle {
                    Layout.preferredWidth: window.s(32)
                    Layout.preferredHeight: window.s(32)
                    radius: window.s(16)
                    color: groupMa.containsMouse ? window.surface2 : "transparent"
                    scale: groupMa.pressed ? 0.88 : 1.0
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                    Text {
                        id: groupIconText
                        anchors.centerIn: parent
                        font.family: "SF Pro "
                        font.pixelSize: window.s(16)
                        color: groupMa.containsMouse ? window.mauve : window.subtext0
                        text: window.groupByApp ? "󰕰" : "󰋚"
                        rotation: window.groupByApp ? 0 : -180
                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: groupMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (notifListView) {
                                notifListView.scrollToTopAndToggle();
                            } else {
                                NotificationService.toggleGroupByApp();
                                window.recordExpandedGroupsAsViewed();
                            }
                        }
                    }
                }

                // DND Toggle Button
                Rectangle {
                    Layout.preferredWidth: window.s(32)
                    Layout.preferredHeight: window.s(32)
                    radius: window.s(16)
                    color: dndMa.containsMouse ? window.surface2 : "transparent"
                    scale: dndMa.pressed ? 0.88 : 1.0
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                    Text {
                        anchors.centerIn: parent
                        font.family: "SF Pro "
                        font.pixelSize: window.s(16)
                        color: window.dndEnabled ? window.mauve : (dndMa.containsMouse ? window.text : window.subtext0)
                        text: window.dndEnabled ? "󰂛" : "󰂚"
                        Behavior on color { ColorAnimation { duration: 150 } }
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
                    color: clearAllMa.containsMouse ? Qt.alpha(window.red, 0.2) : "transparent"
                    scale: clearAllMa.pressed ? 0.88 : 1.0
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                    Text {
                        anchors.centerIn: parent
                        font.family: "SF Pro "
                        font.pixelSize: window.s(15)
                        color: clearAllMa.containsMouse ? window.red : window.subtext0
                        text: "󰅖"
                        Behavior on color { ColorAnimation { duration: 150 } }
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

                property bool isToggleScroll: false

                NumberAnimation {
                    id: scrollUpAnim
                    target: notifListView
                    property: "contentY"
                    duration: 130
                    easing.type: Easing.OutCubic
                    onFinished: {
                        notifListView.positionViewAtBeginning();
                        if (notifListView.isToggleScroll) {
                            notifListView.isToggleScroll = false;
                            NotificationService.toggleGroupByApp();
                            window.recordExpandedGroupsAsViewed();
                        }
                    }
                }

                function scrollToTopAndToggle() {
                    if (notifListView.contentY > 15) {
                        notifListView.isToggleScroll = true;
                        scrollUpAnim.stop();
                        scrollUpAnim.from = notifListView.contentY;
                        scrollUpAnim.to = 0;
                        scrollUpAnim.restart();
                    } else {
                        NotificationService.toggleGroupByApp();
                        window.recordExpandedGroupsAsViewed();
                    }
                }

                function smoothScrollToTop() {
                    if (notifListView.contentY > 15) {
                        notifListView.isToggleScroll = false;
                        scrollUpAnim.stop();
                        scrollUpAnim.from = notifListView.contentY;
                        scrollUpAnim.to = 0;
                        scrollUpAnim.restart();
                    } else {
                        notifListView.positionViewAtBeginning();
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    active: notifListView.moving || notifListView.movingVertically
                    width: window.s(4)
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: window.s(4); radius: window.s(2); color: window.surface2 }
                }

                // Fluid Add / Remove / Displaced Transitions
                Transition {
                    id: addCardTransition
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "x"; from: notifListView.width * 0.35; to: 0; duration: 180; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                    }
                }

                add: window.isInitialLoadComplete ? addCardTransition : null

                // Keep remove transition minimal — card visuals are animated by
                // dismissItemAnim / activateAnim on cardRect before model removal.
                // This just ensures the wrapper collapses cleanly afterward.
                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0.0; duration: 1 }
                }

                move: Transition {
                    NumberAnimation { property: "y"; duration: 180; easing.type: Easing.OutCubic }
                }

                moveDisplaced: Transition {
                    NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
                }

                displaced: Transition {
                    NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
                }

                // --- App Grouping Header ---
                section.property: window.groupByApp ? "appName" : ""
                section.criteria: ViewSection.FullString
                section.delegate: Item {
                    id: secDelegate
                    width: ListView.view ? ListView.view.width : 0
                    height: window.s(36)
                    visible: window.groupByApp
                    clip: true

                    // Inner container that we animate on clear
                    Item {
                        id: secInner
                        width: parent.width
                        height: parent.height
                        transformOrigin: Item.Center

                        property bool groupHasUnseen: NotificationService.getGroupUnseenCount(section) > 0

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
                                            color: secInner.groupHasUnseen ? window.mauve : window.subtext0
                                            text: window.isCollapsed(section) ? "󰅂" : "󰅀"
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }

                                        Text {
                                            text: section.toUpperCase()
                                            font.family: "SF Pro Text"
                                            font.weight: Font.Black
                                            font.pixelSize: window.s(11)
                                            color: secInner.groupHasUnseen ? window.mauve : window.subtext0
                                            Behavior on color { ColorAnimation { duration: 200 } }
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
                                            color: secInner.groupHasUnseen ? Qt.alpha(window.mauve, 0.25) : window.surface2
                                            Behavior on color { ColorAnimation { duration: 200 } }

                                            Text {
                                                id: grpCountText
                                                anchors.centerIn: parent
                                                text: parent.grpCount
                                                font.family: "SF Pro Text"
                                                font.weight: Font.Bold
                                                font.pixelSize: window.s(9)
                                                color: secInner.groupHasUnseen ? window.mauve : window.subtext0
                                                Behavior on color { ColorAnimation { duration: 200 } }
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
                                    scale: grpClearMa.pressed ? 0.85 : 1.0
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

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
                                        onClicked: secDismissAnim.start()
                                    }
                                }
                            }
                        }

                        // Animate header out then clear the group
                        SequentialAnimation {
                            id: secDismissAnim
                            ParallelAnimation {
                                NumberAnimation { target: secInner; property: "opacity"; to: 0.0; duration: 160; easing.type: Easing.InQuad }
                                NumberAnimation { target: secInner; property: "scale"; to: 0.92; duration: 160; easing.type: Easing.InQuad }
                                NumberAnimation { target: secInner; property: "x"; to: notifListView.width * 0.15; duration: 160; easing.type: Easing.InQuad }
                            }
                            ScriptAction {
                                script: window.clearGroup(section)
                            }
                        }
                    }
                }

                // --- Individual Notification Card Delegate ---
                delegate: Item {
                    id: delegateWrapper
                    width: ListView.view ? ListView.view.width : 0
                    z: ListView.view ? (ListView.view.count - index) : 0
                    property bool isHidden: window.groupByApp && window.isCollapsed(model.appName)
                    property bool isDismissing: false
                    property bool isActivating: false

                    height: isHidden ? 0 : cardRect.height + window.s(8)
                    opacity: isHidden ? 0.0 : 1.0
                    visible: height > 0
                    clip: true

                    Behavior on height {
                        enabled: window.isInitialLoadComplete && !delegateWrapper.isDismissing
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        enabled: window.isInitialLoadComplete && !delegateWrapper.isDismissing
                        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                    }

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

                    // Animate card out then remove from model
                    SequentialAnimation {
                        id: dismissItemAnim
                        ParallelAnimation {
                            NumberAnimation { target: cardRect; property: "opacity"; to: 0.0; duration: 140; easing.type: Easing.InQuad }
                            NumberAnimation { target: cardRect; property: "scale"; to: 0.88; duration: 140; easing.type: Easing.InQuad }
                            NumberAnimation { target: cardRect; property: "x"; to: notifListView.width * 0.18; duration: 140; easing.type: Easing.InQuad }
                        }
                        ScriptAction {
                            script: delegateWrapper.removeThisNotif()
                        }
                    }

                    function startDismissItem() {
                        if (delegateWrapper.isDismissing || delegateWrapper.isActivating) return;
                        delegateWrapper.isDismissing = true;
                        dismissItemAnim.start();
                    }

                    SequentialAnimation {
                        id: activateAnim
                        ParallelAnimation {
                            NumberAnimation { target: cardRect; property: "scale"; to: 0.94; duration: 80; easing.type: Easing.OutQuad }
                            NumberAnimation { target: clickFlash; property: "opacity"; from: 0.0; to: 0.28; duration: 80; easing.type: Easing.OutQuad }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: cardRect; property: "x"; to: notifListView.width * 0.22; duration: 120; easing.type: Easing.InCubic }
                            NumberAnimation { target: cardRect; property: "opacity"; to: 0.0; duration: 120; easing.type: Easing.InCubic }
                            NumberAnimation { target: cardRect; property: "scale"; to: 0.88; duration: 120; easing.type: Easing.InCubic }
                            NumberAnimation { target: clickFlash; property: "opacity"; to: 0.0; duration: 120; easing.type: Easing.InCubic }
                        }
                        ScriptAction {
                            script: {
                                if (delegateWrapper.realNotif && delegateWrapper.realNotif.actions) {
                                    for (var i = 0; i < delegateWrapper.realNotif.actions.length; i++) {
                                        if (delegateWrapper.realNotif.actions[i].identifier === "default") {
                                            delegateWrapper.realNotif.actions[i].invoke();
                                            break;
                                        }
                                    }
                                }

                                window.focusApp(model.appName, model.desktopEntry, model.senderPid || 0, model.summary || "");
                                delegateWrapper.removeThisNotif();
                            }
                        }
                    }

                    Rectangle {
                        id: cardRect
                        anchors.top: parent.top
                        width: parent.width
                        height: colLayout.implicitHeight + window.s(20)
                        radius: window.s(12)
                        transformOrigin: Item.Center
                        scale: (delegateWrapper.isActivating || delegateWrapper.isDismissing) ? 0.94 : (cardMa.pressed ? 0.97 : 1.0)
                        color: cardMa.containsMouse ? window.surface2 : window.surface1
                        border.color: model.urgency === 2 ? window.red : (cardMa.containsMouse ? Qt.rgba(window.text.r, window.text.g, window.text.b, 0.25) : Qt.rgba(window.text.r, window.text.g, window.text.b, 0.12))
                        border.width: 1
                        clip: true

                        Behavior on scale {
                            enabled: !activateAnim.running && !dismissItemAnim.running
                            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 250 } }

                        // Subtle Accent Flash Overlay on Click
                        Rectangle {
                            id: clickFlash
                            anchors.fill: parent
                            radius: window.s(12)
                            color: window.blue ? window.blue : window.mauve
                            opacity: 0.0
                        }

                        // Main Card Interaction (Click & Middle Click)
                        MouseArea {
                            id: cardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor

                            onClicked: (mouse) => {
                                if (delegateWrapper.isActivating || delegateWrapper.isDismissing) return;
                                if (mouse.button === Qt.MiddleButton) {
                                    delegateWrapper.startDismissItem();
                                    return;
                                }

                                delegateWrapper.isActivating = true;
                                activateAnim.start();
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

                            // Header Line: Icon, AppName, Unread Dot, Timestamp, Dismiss
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

                                Rectangle {
                                    visible: !model.seen
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: window.s(6)
                                    Layout.preferredHeight: window.s(6)
                                    radius: window.s(3)
                                    color: window.mauve
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
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
                                    scale: itemDismissMa.pressed ? 0.85 : 1.0
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

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
                                        onClicked: delegateWrapper.startDismissItem()
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
                                        scale: btnMa.pressed ? 0.94 : 1.0

                                        property real implicitBtnWidth: btnText.implicitWidth + window.s(16)
                                        property bool isPrimary: index === 0

                                        color: isPrimary ? (btnMa.containsMouse ? window.blue : Qt.darker(window.blue, 1.2)) : (btnMa.containsMouse ? window.surface2 : window.surface0)
                                        border.color: isPrimary ? window.blue : window.surface2
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

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
                                                NotificationService.focusApp(model.appName, model.desktopEntry, model.senderPid || 0, model.summary || "");
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
