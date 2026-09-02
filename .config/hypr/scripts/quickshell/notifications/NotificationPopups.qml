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

    property real uiScale: 1.0

    property var layoutConfig: Registry.getPopupLayout(Screen.width, popupWindow.uiScale)

    WlrLayershell.namespace: "qs-popups"
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: true
        right: true
    }

    margins {
        top: NotificationService.rightIslandBottomY
        right: popupWindow.layoutConfig.marginRight
    }

    Behavior on margins.top {
        NumberAnimation { duration: 280; easing.type: Easing.OutExpo }
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

    function removeToast(uid) {
        NotificationService.removeToast(uid);
    }

    function invokeAction(uid, actionId) {
        NotificationService.invokeAction(uid, actionId);
    }

    function activateCard(appName, desktopEntry, uid) {
        NotificationService.activateCard(appName, desktopEntry, uid);
    }

    function formatTime(timestamp) {
        if (!timestamp) return "Just now";
        let date = new Date(timestamp);
        let h = date.getHours().toString().padStart(2, '0');
        let m = date.getMinutes().toString().padStart(2, '0');
        let timeStr = h + ":" + m;

        let diffMs = Date.now() - timestamp;
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

    Item {
        id: contentWrapper
        anchors.fill: parent

        opacity: (popupWindow.dndEnabled || !NotificationService.isRightWidgetOpen || NotificationService.toasts.count === 0) ? 0.0 : 1.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MatugenColors { id: _theme }

        ListView {
            id: popupList
            anchors.fill: parent
            model: NotificationService.toasts
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
                height: contentCol.implicitHeight + (20 * popupWindow.uiScale)

                property string fullSummary: model.summary || ""
                property string fullBody: model.body || ""
                property int popupUid: model.uid
                property int urgencyVal: model.urgency !== undefined ? model.urgency : 1

                property var actionArray: {
                    try {
                        return model.actionsJson ? JSON.parse(model.actionsJson) : []
                    } catch (e) {
                        return []
                    }
                }

                property int effectiveTimeout: {
                    if (urgencyVal === 2) return 0; // Critical notifications stay persistent
                    return 5000;
                }

                Rectangle {
                    id: popupCard
                    anchors.fill: parent
                    radius: 12 * popupWindow.uiScale
                    color: cardMouseArea.containsMouse ? _theme.surface2 : _theme.surface1
                    border.color: urgencyVal === 2 ? _theme.red : (cardMouseArea.containsMouse ? Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.25) : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.12))
                    border.width: 1
                    clip: true

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    // Auto-Dismiss Timer — PAUSES ON MOUSE HOVER
                    Timer {
                        interval: delegateRoot.effectiveTimeout > 0 ? delegateRoot.effectiveTimeout : 5000
                        running: delegateRoot.effectiveTimeout > 0 && !cardMouseArea.containsMouse
                        onTriggered: popupWindow.removeToast(delegateRoot.popupUid)
                    }

                    // Card Mouse Interaction (Left & Middle Click)
                    MouseArea {
                        id: cardMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: (mouse) => {
                            if (mouse.button === Qt.MiddleButton) {
                                popupWindow.removeToast(delegateRoot.popupUid);
                                return;
                            }
                            popupWindow.activateCard(model.appName, model.desktopEntry, delegateRoot.popupUid);
                        }
                    }

                    ColumnLayout {
                        id: contentCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: popupWindow.layoutConfig.padding
                        anchors.leftMargin: popupWindow.layoutConfig.padding
                        spacing: 5 * popupWindow.uiScale

                        // Header Row: Icon, AppName, Timestamp, Dismiss
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
                                font.weight: Font.Bold
                                font.pixelSize: 11 * popupWindow.uiScale
                                color: _theme.subtext0
                            }

                            Text {
                                text: "• " + popupWindow.formatTime(model.timestamp)
                                font.family: "SF Pro Text"
                                font.pixelSize: 10 * popupWindow.uiScale
                                color: _theme.overlay0
                                visible: model.timestamp !== undefined && model.timestamp > 0
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.preferredWidth: 20 * popupWindow.uiScale
                                Layout.preferredHeight: 20 * popupWindow.uiScale
                                radius: 10 * popupWindow.uiScale
                                color: itemDismissMa.containsMouse ? Qt.alpha(_theme.red, 0.25) : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    font.family: "SF Pro "
                                    font.pixelSize: 10 * popupWindow.uiScale
                                    color: itemDismissMa.containsMouse ? _theme.red : _theme.overlay0
                                    text: "󰅖"
                                }

                                MouseArea {
                                    id: itemDismissMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: popupWindow.removeToast(delegateRoot.popupUid)
                                }
                            }
                        }

                        // Summary Title
                        Text {
                            text: delegateRoot.fullSummary || "Notification"
                            font.family: "SF Pro Text"
                            font.weight: Font.Bold
                            font.pixelSize: 12 * popupWindow.uiScale
                            color: _theme.text
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            textFormat: Text.StyledText
                        }

                        // Body Text
                        Text {
                            text: delegateRoot.fullBody
                            font.family: "SF Pro Text"
                            font.weight: Font.Normal
                            font.pixelSize: 11 * popupWindow.uiScale
                            color: _theme.subtext0
                            linkColor: _theme.blue
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            visible: text !== ""
                            textFormat: Text.StyledText
                            onLinkActivated: (link) => Quickshell.execDetached(["xdg-open", link])
                        }

                        // Preview Image
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

                        // Action Buttons Row
                        Flow {
                            Layout.fillWidth: true
                            Layout.topMargin: delegateRoot.actionArray.length > 0 ? (4 * popupWindow.uiScale) : 0
                            spacing: 6 * popupWindow.uiScale
                            visible: delegateRoot.actionArray.length > 0

                            Repeater {
                                model: delegateRoot.actionArray
                                delegate: Rectangle {
                                    width: Math.min(btnTextToast.implicitWidth + (16 * popupWindow.uiScale), popupCard.width - (28 * popupWindow.uiScale))
                                    height: 26 * popupWindow.uiScale
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
                                        onClicked: {
                                            popupWindow.invokeAction(delegateRoot.popupUid, modelData.id || modelData.identifier);
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
