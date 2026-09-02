pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Item {
    id: root

    Caching { id: paths }

    ListModel { id: historyModel }
    ListModel { id: toastModel }

    property var liveNotifs: ({})
    property int _popupCounter: 0
    property bool isStartup: true

    property bool isRightWidgetOpen: false
    property real rightIslandBottomY: 54

    readonly property alias history: historyModel
    readonly property alias toasts: toastModel
    readonly property int unreadCount: historyModel.count

    Timer {
        interval: 600
        running: true
        onTriggered: root.isStartup = false
    }

    function removeToast(uid) {
        for (let i = 0; i < toastModel.count; i++) {
            if (toastModel.get(i).uid === uid) {
                toastModel.remove(i);
                break;
            }
        }
    }

    function removeHistory(uid) {
        for (let i = 0; i < historyModel.count; i++) {
            if (historyModel.get(i).uid === uid) {
                if (liveNotifs[uid]) delete liveNotifs[uid];
                historyModel.remove(i);
                break;
            }
        }
        removeToast(uid);
        updateNotifCountFile();
    }

    function clearAllHistory() {
        for (let key in liveNotifs) delete liveNotifs[key];
        historyModel.clear();
        toastModel.clear();
        updateNotifCountFile();
    }

    function clearGroup(appName) {
        for (let i = historyModel.count - 1; i >= 0; i--) {
            if (historyModel.get(i).appName === appName) {
                let uid = historyModel.get(i).uid;
                if (liveNotifs[uid]) delete liveNotifs[uid];
                historyModel.remove(i);
            }
        }
        for (let i = toastModel.count - 1; i >= 0; i--) {
            if (toastModel.get(i).appName === appName) {
                toastModel.remove(i);
            }
        }
        updateNotifCountFile();
    }

    function focusApp(appName, desktopEntry) {
        let target = (desktopEntry || appName || "").trim();
        if (!target) return;
        Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/focus_app.sh '" + target.replace(/'/g, "") + "'"]);
    }

    function invokeAction(uid, actionId) {
        let n = liveNotifs[uid];
        if (n && n.actions) {
            for (let i = 0; i < n.actions.length; i++) {
                let act = n.actions[i];
                let actKey = (typeof act === "string") ? act : (act.identifier || act.key || act.id || "");
                if (actKey === actionId) {
                    if (typeof act.invoke === "function") act.invoke();
                    break;
                }
            }
        }
        removeToast(uid);
    }

    function activateCard(appName, desktopEntry, uid) {
        let n = liveNotifs[uid];
        if (n && n.actions) {
            for (let i = 0; i < n.actions.length; i++) {
                let act = n.actions[i];
                let actKey = (typeof act === "string") ? act : (act.identifier || act.key || act.id || "");
                if (actKey === "default" && typeof act.invoke === "function") {
                    act.invoke();
                    break;
                }
            }
        }
        focusApp(appName, desktopEntry);
        removeToast(uid);
    }

    function updateNotifCountFile() {
        let cnt = historyModel.count;
        Quickshell.execDetached(["bash", "-c", "mkdir -p " + paths.runDir + " && echo '" + cnt + "' > " + paths.runDir + "/notif_count"]);
    }

    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: (n) => {
            n.tracked = true;

            let extractedActions = [];
            if (n.actions && n.actions.length > 0) {
                if (typeof n.actions[0] === "string") {
                    for (let i = 0; i < n.actions.length; i += 2) {
                        let actionId = n.actions[i] || "";
                        let actionText = (i + 1 < n.actions.length && n.actions[i + 1]) ? n.actions[i + 1] : actionId;
                        if (actionId !== "default" && actionId !== "") {
                            extractedActions.push({ "id": actionId, "text": actionText });
                        }
                    }
                } else {
                    for (let i = 0; i < n.actions.length; i++) {
                        let act = n.actions[i];
                        if (!act) continue;
                        let actionId = act.key !== undefined ? act.key : (act.identifier !== undefined ? act.identifier : (act.id !== undefined ? act.id : ""));
                        let actionText = act.text !== undefined ? act.text : (act.label !== undefined ? act.label : (act.name !== undefined ? act.name : actionId));
                        if (actionId !== "default" && actionId !== "") {
                            extractedActions.push({ "id": actionId, "text": actionText });
                        }
                    }
                }
            }

            let hints = n.hints || {};
            let desktopEntry = hints["desktop-entry"] || "";
            let urgencyVal = hints["urgency"] !== undefined ? hints["urgency"] : 1;
            let imgPath = hints["image-path"] || hints["image_path"] || hints["image_data"] || "";
            if (imgPath === "" && n.image !== undefined && n.image !== null) imgPath = n.image;

            root._popupCounter++;
            let currentUid = root._popupCounter;

            root.liveNotifs[currentUid] = n;

            let notifData = {
                "appName":      n.appName  !== "" ? n.appName  : "System",
                "summary":      n.summary  !== "" ? n.summary  : "No Title",
                "body":         n.body     !== "" ? n.body     : "",
                "iconPath":     n.appIcon  !== "" ? n.appIcon  : "",
                "imagePath":    imgPath,
                "desktopEntry": desktopEntry,
                "urgency":      urgencyVal,
                "timestamp":    Date.now(),
                "actionsJson":  JSON.stringify(extractedActions),
                "uid":          currentUid
            };

            // Always add to history
            historyModel.insert(0, notifData);
            updateNotifCountFile();

            // If past startup, always route to toastModel and notify dynamic island
            if (!root.isStartup) {
                toastModel.insert(0, notifData);
                root.newToastReceived(currentUid);
            }
        }
    }

    signal newToastReceived(int uid)
}
