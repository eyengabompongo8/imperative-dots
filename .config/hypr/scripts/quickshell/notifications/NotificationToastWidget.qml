import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: toastRoot

    property real uiScale: 1.0

    function s(val) {
        return val * toastRoot.uiScale;
    }

    Caching { id: paths }
    MatugenColors { id: _theme }

    readonly property real targetMasterWidth: s(380)
    readonly property real targetMasterHeight: NotificationService.toasts.count > 0
        ? Math.max(s(40), Math.min(s(650), toastList.contentHeight))
        : 0

    function formatTime(timestamp) {
        if (!timestamp) return "Just now";
        let date = new Date(timestamp);
        let now = new Date();
        let diffMs = now - date;
        let diffMins = Math.floor(diffMs / 60000);
        let diffHours = Math.floor(diffMins / 60);

        if (diffMins < 1) return "Just now";
        if (diffMins < 60) return diffMins + "m ago";
        if (diffHours < 24) {
            let h = date.getHours().toString().padStart(2, '0');
            let m = date.getMinutes().toString().padStart(2, '0');
            return h + ":" + m;
        }
        return (date.getMonth() + 1) + "/" + date.getDate();
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

    ListView {
        id: toastList
        anchors.fill: parent
        model: NotificationService.toasts
        spacing: s(6)
        interactive: contentHeight > height
        clip: true

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 140; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 140; easing.type: Easing.OutExpo }
                NumberAnimation { property: "y"; from: -12; duration: 140; easing.type: Easing.OutBack }
            }
        }

        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0.0; duration: 120; easing.type: Easing.InCubic }
                NumberAnimation { property: "scale"; to: 0.92; duration: 120; easing.type: Easing.InCubic }
            }
        }

        displaced: Transition {
            NumberAnimation { properties: "y"; duration: 140; easing.type: Easing.OutCubic }
        }

        delegate: Item {
            id: cardDelegate
            width: ListView.view.width
            height: cardContentCol.implicitHeight + s(14)

            property string fullSummary: model.summary || ""
            property string fullBody: model.body || ""
            property int popupUid: model.uid
            property int urgencyVal: model.urgency !== undefined ? model.urgency : 1

            property var actionArray: {
                try {
                    return model.actionsJson ? JSON.parse(model.actionsJson) : [];
                } catch (e) {
                    return [];
                }
            }

            property int effectiveTimeout: {
                if (urgencyVal === 2) return 0; // Critical notifications stay persistent
                return 5000;
            }

            // Divider between stacked notifications
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: s(8)
                anchors.rightMargin: s(8)
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: index > 0
            }

            // Subtle interactive hover backdrop
            Rectangle {
                anchors.fill: parent
                radius: s(10)
                color: cardMouse.containsMouse ? Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.25) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // Left Accent Pill (Red for Critical, Mauve for Normal)
            Rectangle {
                width: s(3)
                height: Math.max(s(20), cardContentCol.implicitHeight - s(6))
                anchors.left: parent.left
                anchors.leftMargin: s(2)
                anchors.verticalCenter: parent.verticalCenter
                radius: s(1.5)
                color: cardDelegate.urgencyVal === 2 ? _theme.red : _theme.mauve
            }

            // Auto-Dismiss Timer — Pauses on hover
            Timer {
                id: dismissTimer
                interval: cardDelegate.effectiveTimeout > 0 ? cardDelegate.effectiveTimeout : 5000
                running: cardDelegate.effectiveTimeout > 0 && !cardMouse.containsMouse
                onTriggered: toastRoot.removeToast(cardDelegate.popupUid)
            }

            // Card Click Area
            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) {
                        toastRoot.removeToast(cardDelegate.popupUid);
                        return;
                    }
                    toastRoot.activateCard(model.appName, model.desktopEntry, cardDelegate.popupUid);
                }
            }

            ColumnLayout {
                id: cardContentCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: s(14)
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
                        text: "• " + toastRoot.formatTime(model.timestamp)
                        font.family: "SF Pro Text"
                        font.pixelSize: s(10)
                        color: _theme.overlay0
                        visible: model.timestamp !== undefined && model.timestamp > 0
                    }

                    Item { Layout.fillWidth: true }

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
                            onClicked: toastRoot.removeToast(cardDelegate.popupUid)
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
                    linkColor: _theme.blue
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
                    Layout.preferredHeight: visible ? s(110) : 0
                    fillMode: Image.PreserveAspectCrop
                    clip: true
                }

                // Action Buttons Row (Flow)
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: cardDelegate.actionArray.length > 0 ? s(3) : 0
                    spacing: s(6)
                    visible: cardDelegate.actionArray.length > 0

                    Repeater {
                        model: cardDelegate.actionArray
                        delegate: Rectangle {
                            width: Math.min(btnLabel.implicitWidth + s(16), cardDelegate.width - s(30))
                            height: s(26)
                            radius: s(6)

                            property bool isPrimary: index === 0

                            color: {
                                if (!_theme.blue) return "transparent";
                                if (isPrimary) {
                                    return actionBtnMouse.containsMouse ? _theme.blue : Qt.darker(_theme.blue, 1.2);
                                } else {
                                    return actionBtnMouse.containsMouse ? _theme.surface2 : _theme.surface1;
                                }
                            }

                            border.color: (!_theme.blue) ? "transparent" : (isPrimary ? _theme.blue : _theme.surface2)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                id: btnLabel
                                anchors.centerIn: parent
                                text: modelData.text || "Action"
                                font.family: "SF Pro Text"
                                font.weight: Font.Bold
                                font.pixelSize: s(11)
                                color: isPrimary ? _theme.crust : _theme.text
                                elide: Text.ElideRight
                                width: parent.width - s(8)
                                horizontalAlignment: Text.AlignHCenter
                            }

                            MouseArea {
                                id: actionBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    toastRoot.invokeAction(cardDelegate.popupUid, modelData.id || modelData.identifier);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
