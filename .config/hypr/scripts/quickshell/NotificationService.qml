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
    ListModel { id: actionToastModel }

    property var liveNotifs: ({})
    property int _popupCounter: 0
    property bool isStartup: true

    property bool isRightWidgetOpen: false
    property bool isNotifWidgetOpen: false
    property real rightIslandBottomY: 54

    readonly property alias history: historyModel
    readonly property alias toasts: toastModel
    readonly property alias actionToasts: actionToastModel
    property int unseenCount: 0
    readonly property int unreadCount: unseenCount

    signal newToastReceived(int uid)
    signal inPlaceNotificationReceived(int uid, string appName)

    function dismissAllToasts() {
        toastModel.clear();
    }

    function recountUnseen() {
        let count = 0;
        for (let i = 0; i < historyModel.count; i++) {
            let item = historyModel.get(i);
            if (item && !item.seen) count++;
        }
        unseenCount = count;
    }

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

    function markAsSeen(uid) {
        for (let i = 0; i < historyModel.count; i++) {
            if (historyModel.get(i).uid === uid) {
                if (!historyModel.get(i).seen) {
                    historyModel.setProperty(i, "seen", true);
                    recountUnseen();
                }
                break;
            }
        }
    }

    function markGroupAsSeen(appName) {
        let changed = false;
        for (let i = 0; i < historyModel.count; i++) {
            let item = historyModel.get(i);
            if (item.appName === appName && !item.seen) {
                historyModel.setProperty(i, "seen", true);
                changed = true;
            }
        }
        if (changed) recountUnseen();
    }

    function markAllAsSeen() {
        for (let i = 0; i < historyModel.count; i++) {
            historyModel.setProperty(i, "seen", true);
        }
        recountUnseen();
    }

    function getGroupUnseenCount(appName) {
        let count = 0;
        for (let i = 0; i < historyModel.count; i++) {
            let item = historyModel.get(i);
            if (item.appName === appName && !item.seen) count++;
        }
        return count;
    }

    property bool groupByApp: true

    Process {
        id: groupByAppPoller
        command: ["bash", "-c", "cat '" + paths.getCacheDir("notifications") + "/group_by_app' 2>/dev/null || echo '1'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let val = this.text.trim();
                let enabled = (val !== "0");
                if (root.groupByApp !== enabled) {
                    root.groupByApp = enabled;
                    root.reorderHistory(enabled);
                }
            }
        }
    }

    function toggleGroupByApp() {
        setGroupByApp(!root.groupByApp);
    }

    function setGroupByApp(enabled) {
        if (root.groupByApp === enabled) return;
        root.groupByApp = enabled;
        reorderHistory(enabled);
        Quickshell.execDetached(["bash", "-c", "mkdir -p '" + paths.getCacheDir("notifications") + "' && echo '" + (enabled ? "1" : "0") + "' > '" + paths.getCacheDir("notifications") + "/group_by_app'"]);
    }

    function reorderHistory(isGrouped) {
        if (historyModel.count <= 1) return;

        let items = [];
        for (let i = 0; i < historyModel.count; i++) {
            items.push(historyModel.get(i));
        }

        let targetUids = [];
        if (!isGrouped) {
            items.sort(function(a, b) {
                return (b.timestamp || 0) - (a.timestamp || 0);
            });
            targetUids = items.map(function(item) { return item.uid; });
        } else {
            let groups = {};
            let groupNames = [];
            for (let i = 0; i < items.length; i++) {
                let item = items[i];
                let app = item.appName || "System";
                if (!groups[app]) {
                    groups[app] = [];
                    groupNames.push(app);
                }
                groups[app].push(item);
            }

            for (let app in groups) {
                groups[app].sort(function(a, b) {
                    return (b.timestamp || 0) - (a.timestamp || 0);
                });
            }

            groupNames.sort(function(a, b) {
                let latestA = groups[a][0] ? (groups[a][0].timestamp || 0) : 0;
                let latestB = groups[b][0] ? (groups[b][0].timestamp || 0) : 0;
                return latestB - latestA;
            });

            for (let i = 0; i < groupNames.length; i++) {
                let grp = groups[groupNames[i]];
                for (let j = 0; j < grp.length; j++) {
                    targetUids.push(grp[j].uid);
                }
            }
        }

        for (let targetIdx = 0; targetIdx < targetUids.length; targetIdx++) {
            let desiredUid = targetUids[targetIdx];
            if (historyModel.get(targetIdx).uid !== desiredUid) {
                for (let curIdx = targetIdx + 1; curIdx < historyModel.count; curIdx++) {
                    if (historyModel.get(curIdx).uid === desiredUid) {
                        historyModel.move(curIdx, targetIdx, 1);
                        break;
                    }
                }
            }
        }
    }

    function addHistory(notifData) {
        if (!root.groupByApp) {
            historyModel.insert(0, notifData);
        } else {
            let app = notifData.appName;
            let indices = [];

            for (let i = 0; i < historyModel.count; i++) {
                let item = historyModel.get(i);
                if (item && item.appName === app) {
                    indices.push(i);
                }
            }

            if (indices.length > 0) {
                let alreadyAtTop = true;
                for (let k = 0; k < indices.length; k++) {
                    if (indices[k] !== k) {
                        alreadyAtTop = false;
                        break;
                    }
                }

                if (!alreadyAtTop) {
                    for (let k = 0; k < indices.length; k++) {
                        historyModel.move(indices[k], k, 1);
                    }
                }
            }

            historyModel.insert(0, notifData);
        }
        recountUnseen();
        updateNotifCountFile();
    }

    function removeHistory(uid) {
        let notifObj = liveNotifs[uid];
        if (notifObj && notifObj.tracked) {
            notifObj.tracked = false;
        }
        for (let i = 0; i < historyModel.count; i++) {
            if (historyModel.get(i).uid === uid) {
                if (liveNotifs[uid]) delete liveNotifs[uid];
                historyModel.remove(i);
                break;
            }
        }
        removeToast(uid);
        recountUnseen();
        updateNotifCountFile();
    }

    function clearAllHistory() {
        for (let key in liveNotifs) {
            if (liveNotifs[key] && liveNotifs[key].tracked) {
                liveNotifs[key].tracked = false;
            }
            delete liveNotifs[key];
        }
        historyModel.clear();
        toastModel.clear();
        unseenCount = 0;
        updateNotifCountFile();
    }

    function clearGroup(appName) {
        for (let i = historyModel.count - 1; i >= 0; i--) {
            if (historyModel.get(i).appName === appName) {
                let uid = historyModel.get(i).uid;
                if (liveNotifs[uid]) {
                    if (liveNotifs[uid].tracked) liveNotifs[uid].tracked = false;
                    delete liveNotifs[uid];
                }
                historyModel.remove(i);
            }
        }
        for (let i = toastModel.count - 1; i >= 0; i--) {
            if (toastModel.get(i).appName === appName) {
                toastModel.remove(i);
            }
        }
        recountUnseen();
        updateNotifCountFile();
    }

    function getGroupCount(appName) {
        let count = 0;
        for (let i = 0; i < historyModel.count; i++) {
            if (historyModel.get(i).appName === appName) count++;
        }
        return count;
    }

    function focusApp(appName, desktopEntry, senderPid, summary) {
        let app = (appName || "").trim();
        let entry = (desktopEntry || "").trim();
        let pid = senderPid ? String(senderPid) : "0";
        let sum = (summary || "").trim();
        if (!app && !entry && pid === "0") return;
        Quickshell.execDetached(["bash", paths.home + "/.config/hypr/scripts/focus_app.sh", app, entry, pid, sum]);
    }

    function invokeAction(uid, actionId) {
        markAsSeen(uid);
        let n = liveNotifs[uid];
        if (n && n.actions) {
            let targetId = String(actionId);
            for (let i = 0; i < n.actions.length; i++) {
                let act = n.actions[i];
                if (!act) continue;
                let actKey = (typeof act === "string") ? act : (act.identifier !== undefined ? act.identifier : (act.key !== undefined ? act.key : (act.id !== undefined ? act.id : "")));
                if (String(actKey) === targetId) {
                    if (typeof act.invoke === "function") act.invoke();
                    break;
                }
            }
        }
        removeHistory(uid);
    }

    function activateCard(appName, desktopEntry, uid, senderPid, summary) {
        markAsSeen(uid);
        let n = liveNotifs[uid];
        if (n && n.actions) {
            for (let i = 0; i < n.actions.length; i++) {
                let act = n.actions[i];
                if (!act) continue;
                let actKey = (typeof act === "string") ? act : (act.identifier !== undefined ? act.identifier : (act.key !== undefined ? act.key : (act.id !== undefined ? act.id : "")));
                if (String(actKey) === "default" && typeof act.invoke === "function") {
                    act.invoke();
                    break;
                }
            }
        }
        focusApp(appName, desktopEntry, senderPid, summary);
        removeHistory(uid);
    }

    function removeActionToast(uid) {
        for (let i = 0; i < actionToastModel.count; i++) {
            if (actionToastModel.get(i).uid === uid) {
                actionToastModel.remove(i);
                break;
            }
        }
    }

    function dismissAllActionToasts() {
        actionToastModel.clear();
    }

    function activateLatestNotification() {
        let target = null;
        if (toastModel.count > 0) {
            target = toastModel.get(0);
        } else if (historyModel.count > 0) {
            target = historyModel.get(0);
        }
        if (!target) return;

        let uid = target.uid;
        let appName = target.appName || "System";
        let desktopEntry = target.desktopEntry || "";
        let senderPid = target.senderPid || 0;
        let summary = target.summary || "";
        let body = target.body || "";
        let iconPath = target.iconPath || "";
        let imagePath = target.imagePath || "";

        // Trigger action & focus
        activateCard(appName, desktopEntry, uid, senderPid, summary);

        // Spawn separate mauve action pop-out
        root._popupCounter++;
        let actionUid = root._popupCounter;
        actionToastModel.insert(0, {
            "uid": actionUid,
            "sourceUid": uid,
            "appName": appName,
            "summary": summary,
            "body": body,
            "iconPath": iconPath,
            "imagePath": imagePath,
            "desktopEntry": desktopEntry,
            "senderPid": senderPid,
            "timestamp": Date.now(),
            "actionPerformed": true
        });
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
                        let actionId = act.identifier !== undefined ? act.identifier : (act.key !== undefined ? act.key : (act.id !== undefined ? act.id : ""));
                        let actionText = act.text !== undefined ? act.text : (act.label !== undefined ? act.label : (act.name !== undefined ? act.name : String(actionId)));
                        if (String(actionId) !== "default" && String(actionId) !== "") {
                            extractedActions.push({ "id": String(actionId), "text": String(actionText) });
                        }
                    }
                }
            }

            let hints = n.hints || {};
            let desktopEntry = hints["desktop-entry"] || "";
            let senderPid = hints["sender-pid"] || hints["pid"] || hints["x-kde-originating-pid"] || 0;
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
                "senderPid":    senderPid,
                "urgency":      urgencyVal,
                "timestamp":    Date.now(),
                "actionsJson":  JSON.stringify(extractedActions),
                "uid":          currentUid,
                "seen":         false
            };

            // Always add to history (grouped by application)
            root.addHistory(notifData);

            // If past startup, route to toastModel if widget is closed, or notify open widget in-place
            if (!root.isStartup) {
                if (!root.isNotifWidgetOpen) {
                    toastModel.insert(0, notifData);
                    root.newToastReceived(currentUid);
                } else {
                    root.inPlaceNotificationReceived(currentUid, notifData.appName);
                }
            }
        }
    }
}
