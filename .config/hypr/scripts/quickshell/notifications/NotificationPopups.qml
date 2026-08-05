import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../"
import "../WindowRegistry.js" as Registry

PanelWindow {
    id: popupWindow

    Caching { id: paths }

    property var popupModel
    property real uiScale: 1.0

    // Local map — live QObjects stored directly
    property var _notifMap: ({})

    function storeNotif(uid, notif) {
        _notifMap[uid] = notif;
    }

    function getNotif(uid) {
        return _notifMap[uid] || null;
    }

    function removeNotif(uid) {
        delete _notifMap[uid];
        popupWindow.removeRequested(uid);
    }

    signal removeRequested(int uid)

    property var layoutConfig: Registry.getPopupLayout(Screen.width, popupWindow.uiScale)

    WlrLayershell.namespace: "qs-popups"
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: true
        right: true
    }

    margins {
        top: popupWindow.layoutConfig.marginTop
        right: popupWindow.layoutConfig.marginRight
    }

    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"

    width: popupWindow.layoutConfig.w
    height: Math.min(popupList.contentHeight, Screen.height * 0.8)

    Behavior on height {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    property bool dndEnabled: false

    Process {
        id: dndPoller
        command: ["bash", "-c", "cat '" + paths.getCacheDir("dnd") + "/state' 2>/dev/null || echo '0'"]
        stdout: StdioCollector {
            onStreamFinished: popupWindow.dndEnabled = (this.text.trim() === "1")
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: dndPoller.running = true
    }

    function focusApp(appName, desktopEntry) {
        let target = (desktopEntry || appName || "").trim();
        if (!target) return;
        Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/focus_app.sh '" + target.replace(/'/g, "") + "'"]);
    }

    Item {
        id: contentWrapper
        anchors.fill: parent

        opacity: popupWindow.dndEnabled ? 0.0 : 1.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MatugenColors { id: _theme }

        property var blobPalette1: [_theme.mauve, _theme.blue, _theme.peach, _theme.green, _theme.pink]
        property var blobPalette2: [_theme.sapphire, _theme.teal, _theme.maroon, _theme.yellow, _theme.red]

        property real globalOrbitAngle: 0
        NumberAnimation on globalOrbitAngle {
            from: 0; to: Math.PI * 2; duration: 25000; loops: Animation.Infinite; running: true
        }

        ListView {
            id: popupList
            anchors.fill: parent
            model: popupWindow.popupModel
            spacing: popupWindow.layoutConfig.spacing
            interactive: false
            clip: false

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "x"; from: popupWindow.width * 0.4; to: 0; duration: 220; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
                }
            }

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0.0; duration: 150; easing.type: Easing.InCubic }
                    NumberAnimation { property: "x"; to: popupWindow.width * 0.4; duration: 150; easing.type: Easing.InCubic }
                    NumberAnimation { property: "scale"; to: 0.9; duration: 150; easing.type: Easing.InCubic }
                }
            }

            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
            }

            delegate: Item {
                id: delegateRoot
                width: ListView.view.width
                height: contentCol.height + (popupWindow.layoutConfig.padding * 2)

                property string fullSummary: model.summary || ""
                property string fullBody: model.body || ""
                property int typeLenSum: 0
                property int typeLenBody: 0
                property int popupUid: model.uid

                property var sourceNotif: popupWindow.getNotif(model.uid)

                property var actionArray: {
                    try {
                        return model.actionsJson ? JSON.parse(model.actionsJson) : []
                    } catch (e) {
                        return []
                    }
                }

                property int effectiveTimeout: {
                    if (model.urgency === 2) return 0; // Critical notifications stay persistent
                    var n = popupWindow.getNotif(model.uid);
                    if (!n || n.timeout === undefined) return 5000;
                    if (n.timeout === 0) return 0;
                    if (n.timeout > 0) return n.timeout;
                    return 5000;
                }

                Connections {
                    target: delegateRoot.sourceNotif || null
                    function onClosed() {
                        popupWindow.removeNotif(delegateRoot.popupUid);
                    }
                }

                ParallelAnimation {
                    running: true
                    NumberAnimation {
                        target: delegateRoot; property: "typeLenSum"
                        from: 0; to: fullSummary.length
                        duration: Math.min(fullSummary.length * 20, 600)
                        easing.type: Easing.OutCubic
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 150 }
                        NumberAnimation {
                            target: delegateRoot; property: "typeLenBody"
                            from: 0; to: fullBody.length
                            duration: Math.min(fullBody.length * 15, 1200)
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    id: popupCard
                    anchors.fill: parent
                    radius: popupWindow.layoutConfig.radius
                    color: _theme.base
                    border.color: model.urgency === 2 ? _theme.red : _theme.surface1
                    border.width: model.urgency === 2 ? 2 : 1
                    clip: true

                    property color blob1Color: contentWrapper.blobPalette1[index % 5]
                    property color blob2Color: contentWrapper.blobPalette2[index % 5]

                    Rectangle {
                        width: parent.width * 0.7; height: width; radius: width / 2
                        x: (parent.width / 2 - width / 2) + Math.cos(contentWrapper.globalOrbitAngle * 2 + index) * 60
                        y: (parent.height / 2 - height / 2) + Math.sin(contentWrapper.globalOrbitAngle * 2 + index) * 30
                        color: popupCard.blob1Color
                        opacity: 0.12
                    }

                    Rectangle {
                        width: parent.width * 0.5; height: width; radius: width / 2
                        x: (parent.width / 2 - width / 2) + Math.sin(contentWrapper.globalOrbitAngle * 1.5 - index) * -50
                        y: (parent.height / 2 - height / 2) + Math.cos(contentWrapper.globalOrbitAngle * 1.5 - index) * -40
                        color: popupCard.blob2Color
                        opacity: 0.10
                    }

                    // Auto-Dismiss Timer — PAUSES ON MOUSE HOVER
                    Timer {
                        interval: delegateRoot.effectiveTimeout > 0 ? delegateRoot.effectiveTimeout : 5000
                        running: delegateRoot.effectiveTimeout > 0 && !cardMouseArea.containsMouse
                        onTriggered: popupWindow.removeNotif(delegateRoot.popupUid)
                    }

                    // Card Mouse Interaction (Left & Middle Click)
                    MouseArea {
                        id: cardMouseArea
                        anchors.fill: parent
                        z: 1
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: (mouse) => {
                            if (mouse.button === Qt.MiddleButton) {
                                popupWindow.removeNotif(delegateRoot.popupUid);
                                return;
                            }

                            var n = popupWindow.getNotif(delegateRoot.popupUid);
                            if (n && n.actions) {
                                for (var i = 0; i < n.actions.length; i++) {
                                    if (n.actions[i].identifier === "default") {
                                        n.actions[i].invoke();
                                        break;
                                    }
                                }
                            }
                            popupWindow.focusApp(model.appName, model.desktopEntry);
                            Qt.callLater(function() { popupWindow.removeNotif(delegateRoot.popupUid); });
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: popupCard.radius
                            color: _theme.surface0
                            opacity: parent.containsMouse ? 0.3 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                        }
                    }

                    ColumnLayout {
                        id: contentCol
                        z: 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: popupWindow.layoutConfig.padding
                        spacing: 6 * popupWindow.uiScale

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6 * popupWindow.uiScale

                            Image {
                                visible: model.iconPath !== undefined && model.iconPath !== ""
                                source: model.iconPath ? (model.iconPath.startsWith("/") ? "file://" + model.iconPath : "image://icon/" + model.iconPath) : ""
                                Layout.preferredWidth: 16 * popupWindow.uiScale
                                Layout.preferredHeight: 16 * popupWindow.uiScale
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                text: model.appName || "System"
                                font.family: "SF Pro Text"
                                font.weight: Font.Medium
                                font.pixelSize: 12 * popupWindow.uiScale
                                color: _theme.overlay1
                                Layout.fillWidth: true
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: hiddenSummary.implicitHeight

                            Text {
                                id: hiddenSummary
                                text: delegateRoot.fullSummary
                                width: parent.width
                                font.family: "SF Pro Text"
                                font.weight: Font.Bold
                                font.pixelSize: 15 * popupWindow.uiScale
                                wrapMode: Text.Wrap
                                visible: false
                            }

                            Text {
                                anchors.fill: parent
                                text: delegateRoot.fullSummary.substring(0, delegateRoot.typeLenSum)
                                font: hiddenSummary.font
                                color: _theme.text
                                wrapMode: Text.Wrap
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: hiddenBody.implicitHeight
                            visible: delegateRoot.fullBody !== ""

                            Text {
                                id: hiddenBody
                                text: delegateRoot.fullBody
                                width: parent.width
                                font.family: "SF Pro Text"
                                font.weight: Font.Medium
                                font.pixelSize: 13 * popupWindow.uiScale
                                wrapMode: Text.Wrap
                                textFormat: Text.StyledText
                                linkColor: _theme.blue
                                visible: false
                            }

                            Text {
                                anchors.fill: parent
                                text: delegateRoot.fullBody.substring(0, delegateRoot.typeLenBody)
                                font: hiddenBody.font
                                color: _theme.subtext0
                                linkColor: _theme.blue
                                wrapMode: Text.Wrap
                                textFormat: Text.StyledText
                                onLinkActivated: (link) => Quickshell.execDetached(["xdg-open", link])
                            }
                        }

                        // Preview Image Thumbnail (if available)
                        Image {
                            id: previewImgToast
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
                            Layout.preferredHeight: visible ? (110 * popupWindow.uiScale) : 0
                            fillMode: Image.PreserveAspectCrop
                            clip: true
                        }

                        // --- INLINE ACTION BUTTONS ---
                        Flow {
                            Layout.fillWidth: true
                            Layout.topMargin: delegateRoot.actionArray.length > 0 ? (6 * popupWindow.uiScale) : 0
                            spacing: 8 * popupWindow.uiScale
                            visible: delegateRoot.actionArray.length > 0

                            Repeater {
                                model: delegateRoot.actionArray
                                delegate: Rectangle {
                                    width: Math.min(btnTextToast.implicitWidth + (16 * popupWindow.uiScale), popupCard.width - (24 * popupWindow.uiScale))
                                    height: 30 * popupWindow.uiScale
                                    radius: 6 * popupWindow.uiScale

                                    property bool isPrimary: index === 0

                                    color: {
                                        if (!_theme.blue) return "transparent";
                                        if (isPrimary) {
                                            return actionMouseArea.containsMouse ? _theme.blue : Qt.darker(_theme.blue, 1.2)
                                        } else {
                                            return actionMouseArea.containsMouse ? _theme.surface2 : _theme.surface1
                                        }
                                    }

                                    border.color: (!_theme.blue) ? "transparent" : (isPrimary ? _theme.blue : _theme.surface2)
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        id: btnTextToast
                                        anchors.centerIn: parent
                                        text: modelData.text || "Action"
                                        font.family: "SF Pro Text"
                                        font.weight: Font.Bold
                                        font.pixelSize: 11 * popupWindow.uiScale
                                        color: isPrimary ? _theme.crust : _theme.text
                                        elide: Text.ElideRight
                                        width: parent.width - (8 * popupWindow.uiScale)
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    MouseArea {
                                        id: actionMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        z: 10

                                        onClicked: {
                                            var n = popupWindow.getNotif(delegateRoot.popupUid);
                                            if (n && n.actions) {
                                                for (var i = 0; i < n.actions.length; i++) {
                                                    if (n.actions[i].identifier === modelData.id) {
                                                        n.actions[i].invoke();
                                                        break;
                                                    }
                                                }
                                            }
                                            popupWindow.focusApp(model.appName, model.desktopEntry);
                                            Qt.callLater(function() { popupWindow.removeNotif(delegateRoot.popupUid); });
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
