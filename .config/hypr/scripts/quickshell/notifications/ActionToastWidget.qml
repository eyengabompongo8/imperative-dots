import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: actionToastRoot

    property real uiScale: 1.0

    function s(val) {
        return val * actionToastRoot.uiScale;
    }

    Caching { id: paths }
    MatugenColors { id: _theme }

    readonly property color mauve: _theme.mauve || "#cba6f7"
    readonly property real targetMasterWidth: s(380)
    readonly property real targetMasterHeight: NotificationService.actionToasts.count > 0
        ? Math.max(s(40), Math.min(s(650), actionToastList.contentHeight))
        : 0

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

    function removeActionToast(uid) {
        NotificationService.removeActionToast(uid);
    }

    ListView {
        id: actionToastList
        anchors.fill: parent
        model: NotificationService.actionToasts
        spacing: s(6)
        interactive: contentHeight > height
        clip: true

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: ListView.view.width * 0.35; to: 0; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
            }
        }

        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0.0; duration: 150; easing.type: Easing.InCubic }
                NumberAnimation { property: "x"; to: ListView.view.width * 0.35; duration: 150; easing.type: Easing.InCubic }
                NumberAnimation { property: "scale"; to: 0.92; duration: 150; easing.type: Easing.InCubic }
            }
        }

        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
        }

        delegate: Item {
            id: cardDelegate
            width: ListView.view.width
            height: cardContentCol.implicitHeight + s(14)

            property string fullSummary: model.summary || ""
            property string fullBody: model.body || ""
            property int popupUid: model.uid

            // Card backdrop with Clean Mauve Highlight
            Rectangle {
                anchors.fill: parent
                radius: s(12)
                color: cardMouse.containsMouse 
                    ? Qt.rgba(actionToastRoot.mauve.r, actionToastRoot.mauve.g, actionToastRoot.mauve.b, 0.16) 
                    : Qt.rgba(actionToastRoot.mauve.r, actionToastRoot.mauve.g, actionToastRoot.mauve.b, 0.08)
                border.color: cardMouse.containsMouse 
                    ? Qt.lighter(actionToastRoot.mauve, 1.15) 
                    : actionToastRoot.mauve
                border.width: 1.5

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            // Auto-Dismiss Timer (4000ms, pauses on hover)
            Timer {
                id: dismissTimer
                interval: 4000
                running: !cardMouse.containsMouse
                onTriggered: actionToastRoot.removeActionToast(cardDelegate.popupUid)
            }

            // Click Area to dismiss
            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    actionToastRoot.removeActionToast(cardDelegate.popupUid);
                }
            }

            ColumnLayout {
                id: cardContentCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: s(10)
                anchors.rightMargin: s(8)
                anchors.topMargin: s(7)
                spacing: s(4)

                // Header Row: App Icon, App Name, Time, Dismiss Button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: s(6)

                    Image {
                        visible: model.iconPath !== undefined && model.iconPath !== ""
                        source: model.iconPath ? (model.iconPath.startsWith("/") ? "file://" + model.iconPath : "image://icon/" + model.iconPath) : ""
                        Layout.preferredWidth: s(16)
                        Layout.preferredHeight: s(16)
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        text: model.appName || "System"
                        font.family: "SF Pro Text"
                        font.weight: Font.Bold
                        font.pixelSize: s(11)
                        color: _theme.subtext0
                    }

                    Text {
                        text: "• " + actionToastRoot.formatTime(model.timestamp)
                        font.family: "SF Pro Text"
                        font.pixelSize: s(10)
                        color: _theme.overlay0
                        visible: model.timestamp !== undefined && model.timestamp > 0
                    }

                    Item { Layout.fillWidth: true }

                    // Dismiss Button
                    Rectangle {
                        Layout.preferredWidth: s(20)
                        Layout.preferredHeight: s(20)
                        radius: s(10)
                        color: dismissBtnMouse.containsMouse ? Qt.alpha(_theme.red, 0.25) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            font.family: "SF Pro "
                            font.pixelSize: s(10)
                            color: dismissBtnMouse.containsMouse ? _theme.red : _theme.overlay0
                            text: "󰅖"
                        }

                        MouseArea {
                            id: dismissBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: actionToastRoot.removeActionToast(cardDelegate.popupUid)
                        }
                    }
                }

                // Summary / Title
                Text {
                    text: cardDelegate.fullSummary || "Notification"
                    font.family: "SF Pro Text"
                    font.weight: Font.Bold
                    font.pixelSize: s(12)
                    color: _theme.text
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    textFormat: Text.StyledText
                }

                // Body
                Text {
                    text: cardDelegate.fullBody
                    font.family: "SF Pro Text"
                    font.weight: Font.Normal
                    font.pixelSize: s(11)
                    color: _theme.subtext0
                    linkColor: actionToastRoot.mauve
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    visible: text !== ""
                    textFormat: Text.StyledText
                    onLinkActivated: (link) => Quickshell.execDetached(["xdg-open", link])
                }

                // Preview Image if present
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
                    Layout.preferredHeight: visible ? s(100) : 0
                    fillMode: Image.PreserveAspectCrop
                    clip: true
                }
            }
        }
    }
}
