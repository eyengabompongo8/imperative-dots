import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
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
    property int selectedIndex: -1
    property bool isUserSelecting: false
    property real monWidth: 1920
    property real monHeight: 1080
    property var workspacesData: []

    Timer {
        id: focusTimer
        interval: 50
        running: true
        repeat: false
        onTriggered: window.forceActiveFocus()
    }

    function syncSelectedIndex() {
        if (!window.isUserSelecting || window.selectedIndex < 0 || window.selectedIndex >= window.workspacesData.length) {
            if (window.workspacesData && window.workspacesData.length > 0) {
                let idx = window.workspacesData.findIndex(function(w) { return w.id === window.activeWorkspaceId; });
                if (idx !== -1) {
                    window.selectedIndex = idx;
                } else {
                    window.selectedIndex = 0;
                }
            }
        }
    }

    // Monocle window aspect ratio (usable workspace area: monWidth / usable height)
    readonly property real monocleRatio: (monWidth > 0 && monHeight > 60) ? ((monWidth - 12) / (monHeight - 68)) : (16.0 / 9.0)
    readonly property real targetMasterWidth: window.s(980)
    readonly property real targetMasterHeight: Math.round(2 * (((targetMasterWidth - window.s(44)) / 4) / monocleRatio + window.s(18)) + window.s(72))

    // Drag & Drop State Tracking
    property string draggedWindowAddress: ""
    property int draggedFromWs: 0
    property bool isDragging: false
    property bool isOverTrash: false
    property int draggedWorkspaceId: 0
    property bool isDraggingWorkspace: false
    property bool isOverTrashWs: false


    // Icon overrides & class map
    readonly property var iconOverrides: ({
        "zen": "zen-browser",
        "code": "com.visualstudio.code",
        "code-oss": "com.visualstudio.code.oss",
        "obs": "com.obsproject.Studio"
    })

    function resolveIcon(cls) {
        if (!cls) return "application-x-executable";
        let raw = cls.toString().trim();
        let key = raw.toLowerCase();
        if (iconOverrides[key]) return iconOverrides[key];

        // 1. Quickshell native XDG DesktopEntries lookup
        if (typeof DesktopEntries !== "undefined") {
            let entry = DesktopEntries.heuristicLookup(raw) || DesktopEntries.byId(raw) || DesktopEntries.byId(key);
            if (entry && entry.icon) return entry.icon;

            // Match StartupWMClass across desktop entries (standard for Obsidian, Spotify, etc.)
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

        // 2. Reverse-domain fallback: e.g. "md.obsidian.Obsidian" -> "obsidian"
        if (key.indexOf(".") !== -1) {
            let parts = key.split(".");
            let last = parts[parts.length - 1];
            if (iconOverrides[last]) return iconOverrides[last];
            if (typeof DesktopEntries !== "undefined") {
                let entry = DesktopEntries.heuristicLookup(last) || DesktopEntries.byId(last);
                if (entry && entry.icon) return entry.icon;
                if (DesktopEntries.applications && DesktopEntries.applications.values) {
                    let apps = DesktopEntries.applications.values;
                    for (let i = 0; i < apps.length; i++) {
                        let app = apps[i];
                        if (app && (app.id.toLowerCase() === last || (app.name && app.name.toLowerCase() === last))) {
                            if (app.icon) return app.icon;
                        }
                    }
                }
            }
            if (last && last.length > 2) return last;
        }

        return key;
    }

    function computeVirtualTilingBounds(windows, monW, monH) {
        let n = windows.length;
        if (n === 0) return;
        let gap = 12;

        function splitRect(rect, count) {
            if (count === 1) return [rect];
            let x = rect[0], y = rect[1], w = rect[2], h = rect[3];
            if (count === 2) {
                if (w >= h) {
                    let w1 = Math.max(100, Math.floor((w - gap) / 2));
                    let w2 = Math.max(100, w - w1 - gap);
                    return [[x, y, w1, h], [x + w1 + gap, y, w2, h]];
                } else {
                    let h1 = Math.max(80, Math.floor((h - gap) / 2));
                    let h2 = Math.max(80, h - h1 - gap);
                    return [[x, y, w, h1], [x, y + h1 + gap, w, h2]];
                }
            }
            let half = Math.floor(count / 2);
            let rest = count - half;
            if (w >= h) {
                let w1 = Math.max(100, Math.floor((w - gap) / 2));
                let w2 = Math.max(100, w - w1 - gap);
                return splitRect([x, y, w1, h], half).concat(splitRect([x + w1 + gap, y, w2, h], rest));
            } else {
                let h1 = Math.max(80, Math.floor((h - gap) / 2));
                let h2 = Math.max(80, h - h1 - gap);
                return splitRect([x, y, w, h1], half).concat(splitRect([x, y + h1 + gap, w, h2], rest));
            }
        }

        let rects = splitRect([0, 0, monW, monH], n);
        for (let i = 0; i < n && i < rects.length; i++) {
            let r = rects[i];
            windows[i].at = [Math.floor(r[0]), Math.floor(r[1])];
            windows[i].size = [Math.floor(r[2]), Math.floor(r[3])];
        }
    }

    function fetchOverviewData() {
        if (typeof Hyprland === "undefined") return;

        let activeWsId = 1;
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id) {
            activeWsId = Hyprland.focusedWorkspace.id;
        } else if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace && Hyprland.focusedMonitor.activeWorkspace.id) {
            activeWsId = Hyprland.focusedMonitor.activeWorkspace.id;
        }
        window.activeWorkspaceId = activeWsId;

        let monW = 1920;
        let monH = 1080;
        if (Hyprland.focusedMonitor) {
            monW = Hyprland.focusedMonitor.width || 1920;
            monH = Hyprland.focusedMonitor.height || 1080;
        }
        window.monWidth = monW;
        window.monHeight = monH;

        let totalWs = window.workspaceCount || 8;
        let wsMap = {};
        // Build layout lookup from Hyprland workspace objects
        let wsLayouts = {};
        if (Hyprland.workspaces && Hyprland.workspaces.values) {
            let wsList = Hyprland.workspaces.values;
            for (let w = 0; w < wsList.length; w++) {
                let ws = wsList[w];
                if (ws && ws.id !== undefined && ws.lastIpcObject) {
                    wsLayouts[ws.id] = ws.lastIpcObject.tiledLayout || "monocle";
                }
            }
        }

        for (let i = 1; i <= totalWs; i++) {
            wsMap[i] = {
                id: i,
                name: i.toString(),
                isActive: (i === activeWsId),
                isOccupied: false,
                layout: wsLayouts[i] || "monocle",
                windows: []
            };
        }

        let toplevels = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < toplevels.length; i++) {
            let t = toplevels[i];
            if (!t) continue;
            let ipc = t.lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true) continue;

            let wsId = null;
            if (t.workspace && t.workspace.id !== undefined && t.workspace.id !== null) {
                wsId = t.workspace.id;
            }
            if (wsId === null && typeof Hyprland !== "undefined" && Hyprland.workspaces) {
                let wss = Hyprland.workspaces.values || [];
                for (let w = 0; w < wss.length; w++) {
                    let wObj = wss[w];
                    if (wObj && wObj.toplevels && wObj.toplevels.values) {
                        let wTls = wObj.toplevels.values;
                        if (wTls.indexOf(t) !== -1) {
                            wsId = wObj.id;
                            break;
                        }
                    }
                }
            }
            if (wsId === null && ipc.workspace && ipc.workspace.id !== undefined && ipc.workspace.id !== null) {
                wsId = ipc.workspace.id;
            }

            if (wsId !== null && wsMap[wsId]) {
                let cls = ipc["class"] || ipc["initialClass"] || "application-x-executable";
                let icon = resolveIcon(cls);
                let rawAddr = (ipc && ipc.address) ? ipc.address : (t && t.address ? t.address : "");
                let addr = "";
                if (typeof rawAddr === "number") {
                    addr = "0x" + rawAddr.toString(16);
                } else if (typeof rawAddr === "string" && rawAddr.length > 0) {
                    addr = (rawAddr.startsWith("0x") || rawAddr.startsWith("0X")) ? rawAddr : ("0x" + rawAddr);
                }

                wsMap[wsId].isOccupied = true;
                wsMap[wsId].windows.push({
                    address: addr,
                    title: t.title || ipc.title || "Window",
                    "class": cls,
                    icon: icon,
                    at: ipc.at ? [ipc.at[0], ipc.at[1]] : [0, 0],
                    size: ipc.size ? [ipc.size[0], ipc.size[1]] : [400, 300],
                    floating: Boolean(ipc.floating),
                    fullscreen: parseInt(ipc.fullscreen || 0),
                    focusHistoryID: (ipc.focusHistoryID !== undefined) ? ipc.focusHistoryID : 99
                });
            }
        }

        let resultList = [];
        for (let i = 1; i <= totalWs; i++) {
            let item = wsMap[i];
            item.windows.sort((a, b) => a.focusHistoryID - b.focusHistoryID);
            window.computeVirtualTilingBounds(item.windows, monW, monH);

            // Preserve existing array reference if windows list is identical to prevent QML Repeater from recreating delegates
            let prevWs = (window.workspacesData && (i - 1) < window.workspacesData.length) ? window.workspacesData[i - 1] : null;
            if (prevWs && prevWs.windows && prevWs.windows.length === item.windows.length) {
                let match = true;
                for (let w = 0; w < item.windows.length; w++) {
                    let nw = item.windows[w];
                    let pw = prevWs.windows[w];
                    if (nw.address !== pw.address ||
                        nw.icon !== pw.icon ||
                        nw.title !== pw.title ||
                        nw.at[0] !== pw.at[0] || nw.at[1] !== pw.at[1] ||
                        nw.size[0] !== pw.size[0] || nw.size[1] !== pw.size[1]) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    item.windows = prevWs.windows;
                }
            }

            resultList.push(item);
        }

        window.workspacesData = resultList;
        window.syncSelectedIndex();
    }

    function getToplevelForAddress(addr) {
        if (!addr || typeof Hyprland === "undefined" || !Hyprland.toplevels) return null;
        let target = addr.toString().replace(/^0x/i, "").toLowerCase();
        let list = Hyprland.toplevels.values;
        for (let i = 0; i < list.length; i++) {
            let htl = list[i];
            if (!htl) continue;
            let raw = (htl.lastIpcObject && htl.lastIpcObject.address) ? htl.lastIpcObject.address : htl.address;
            if (raw) {
                let htlAddr = (typeof raw === "number") ? raw.toString(16).toLowerCase() : raw.toString().replace(/^0x/i, "").toLowerCase();
                if (htlAddr === target) {
                    return htl.wayland || null;
                }
            }
        }
        return null;
    }



    Timer {
        id: reSyncTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (typeof Hyprland !== "undefined") {
                if (typeof Hyprland.refreshMonitors === "function") Hyprland.refreshMonitors();
                if (typeof Hyprland.refreshWorkspaces === "function") Hyprland.refreshWorkspaces();
                if (typeof Hyprland.refreshToplevels === "function") Hyprland.refreshToplevels();
            }
            window.fetchOverviewData();
        }
    }

    Connections {
        target: Hyprland || null
        function onRawEvent(event) {
            if (!event || !window.visible) return;
            let evName = event.name;
            if (evName === "workspace" || evName === "workspacev2" ||
                evName === "openwindow" || evName === "closewindow" ||
                evName === "movewindow" || evName === "movewindowv2" ||
                evName === "changefloatingmode" || evName === "fullscreen") {
                if (!window.isDragging && !window.isDraggingWorkspace) {
                    reSyncTimer.restart();
                }
            }
        }
        function onFocusedWorkspaceChanged() {
            if (window.visible && !window.isDragging && !window.isDraggingWorkspace) {
                reSyncTimer.restart();
            }
        }
    }

    Component.onCompleted: {
        window.fetchOverviewData();
        focusTimer.restart();
        introPhaseAnim.restart();
    }

    Connections {
        target: window
        function onVisibleChanged() {
            window.draggedWorkspaceId = 0;
            window.isDraggingWorkspace = false;
            window.isDragging = false;
            window.draggedWindowAddress = "";
            window.draggedFromWs = 0;
            if (window.visible) {
                window.isUserSelecting = false;
                window.selectedIndex = -1;
                window.fetchOverviewData();
                focusTimer.restart();
                window.forceActiveFocus();
                introPhaseAnim.restart();
            }
        }
    }

    // -------------------------------------------------------------------------
    // HYPRLAND LUA DISPATCH ACTIONS
    // -------------------------------------------------------------------------
    function focusWorkspace(wsId) {
        if (!wsId) return;
        Quickshell.execDetached(["bash", "-c", "hyprctl dispatch \"hl.dsp.focus({ workspace = " + wsId.toString() + " })\""]);
        closeOverview();
    }

    function focusWindow(address) {
        if (!address) return;
        let formattedAddr = address.toString();
        if (!formattedAddr.startsWith("0x") && !formattedAddr.startsWith("0X")) {
            formattedAddr = "0x" + formattedAddr;
        }
        Quickshell.execDetached(["bash", "-c", "hyprctl dispatch \"hl.dsp.focus({ window = 'address:" + formattedAddr + "' })\""]);
        closeOverview();
    }

    function closeWindow(address) {
        window.isDragging = false;
        window.draggedWindowAddress = "";
        window.draggedFromWs = 0;
        if (!address) return;
        let formattedAddr = address.toString();
        if (!formattedAddr.startsWith("0x") && !formattedAddr.startsWith("0X")) {
            formattedAddr = "0x" + formattedAddr;
        }

        // Instant optimistic UI update: remove window from workspacesData
        if (window.workspacesData && window.workspacesData.length > 0) {
            let data = window.workspacesData.slice();
            for (let i = 0; i < data.length; i++) {
                let ws = Object.assign({}, data[i]);
                if (ws.windows && ws.windows.length > 0) {
                    let winIdx = ws.windows.findIndex(function(w) {
                        return w.address === address || w.address === formattedAddr;
                    });
                    if (winIdx !== -1) {
                        let wins = ws.windows.slice();
                        wins.splice(winIdx, 1);
                        ws.windows = wins;
                        ws.isOccupied = wins.length > 0;
                        data[i] = ws;
                        break;
                    }
                }
            }
            window.workspacesData = data;
        }

        Quickshell.execDetached(["bash", "-c", "hyprctl dispatch \"hl.dsp.focus({ window = 'address:" + formattedAddr + "' })\" && hyprctl dispatch \"hl.dsp.window.close()\""]);
        reSyncTimer.restart();
    }

    function moveWindowToWorkspace(address, targetWsId) {
        window.isDragging = false;
        window.draggedWindowAddress = "";
        window.draggedFromWs = 0;
        if (!address || !targetWsId) return;

        let formattedAddr = address.toString();
        if (!formattedAddr.startsWith("0x") && !formattedAddr.startsWith("0X")) {
            formattedAddr = "0x" + formattedAddr;
        }

        // 1. Optimistic UI update: move window across workspacesData immediately
        if (window.workspacesData && window.workspacesData.length > 0) {
            let data = window.workspacesData.slice();
            let movedWin = null;
            for (let i = 0; i < data.length; i++) {
                let ws = Object.assign({}, data[i]);
                if (ws.windows && ws.windows.length > 0) {
                    let winIdx = ws.windows.findIndex(function(w) {
                        return w.address === address || w.address === formattedAddr;
                    });
                    if (winIdx !== -1) {
                        let wins = ws.windows.slice();
                        movedWin = wins.splice(winIdx, 1)[0];
                        window.computeVirtualTilingBounds(wins, window.monWidth, window.monHeight);
                        ws.windows = wins;
                        ws.isOccupied = wins.length > 0;
                        data[i] = ws;
                        break;
                    }
                }
            }
            if (movedWin) {
                let targetIdx = data.findIndex(function(w) { return w.id === targetWsId; });
                if (targetIdx !== -1) {
                    let targetWs = Object.assign({}, data[targetIdx]);
                    let wins = targetWs.windows ? targetWs.windows.slice() : [];
                    wins.push(movedWin);
                    window.computeVirtualTilingBounds(wins, window.monWidth, window.monHeight);
                    targetWs.windows = wins;
                    targetWs.isOccupied = true;
                    data[targetIdx] = targetWs;
                }
                window.workspacesData = data;
            }
        }

        // 2. Dispatch window move to Hyprland
        Quickshell.execDetached(["bash", "-c", "hyprctl dispatch \"hl.dsp.window.move({ workspace = " + targetWsId.toString() + ", follow = false, window = 'address:" + formattedAddr + "' })\""]);
        reSyncTimer.restart();
    }

    function swapWorkspaces(wsA, wsB) {
        window.isDraggingWorkspace = false;
        window.draggedWorkspaceId = 0;
        if (!wsA || !wsB || wsA === wsB) return;

        let winsA = [];
        let winsB = [];
        let layoutA = "";
        let layoutB = "";

        // 1. Instant optimistic UI update + capture windows + layouts
        if (window.workspacesData && window.workspacesData.length > 0) {
            let idxA = window.workspacesData.findIndex(function(w) { return w.id === wsA; });
            let idxB = window.workspacesData.findIndex(function(w) { return w.id === wsB; });
            if (idxA !== -1 && idxB !== -1) {
                let data = window.workspacesData.slice();
                let itemA = Object.assign({}, data[idxA]);
                let itemB = Object.assign({}, data[idxB]);
                winsA = itemA.windows ? itemA.windows.slice() : [];
                winsB = itemB.windows ? itemB.windows.slice() : [];
                layoutA = itemA.layout || "";
                layoutB = itemB.layout || "";
                let tempWins = itemA.windows;
                let tempOcc = itemA.isOccupied;
                let tempLayout = itemA.layout;
                itemA.windows = itemB.windows;
                itemA.isOccupied = itemB.isOccupied;
                itemA.layout = itemB.layout;
                itemB.windows = tempWins;
                itemB.isOccupied = tempOcc;
                itemB.layout = tempLayout;
                data[idxA] = itemA;
                data[idxB] = itemB;
                window.workspacesData = data;
            }
        }

        // Sort helper: tiled by spatial position (X then Y), floating by focusHistoryID descending
        function sortedForMove(wins) {
            let tiled = wins.filter(function(w) { return !w.floating; });
            let floating = wins.filter(function(w) { return w.floating; });
            tiled.sort(function(a, b) {
                let ax = a.at ? a.at[0] : 0, ay = a.at ? a.at[1] : 0;
                let bx = b.at ? b.at[0] : 0, by = b.at ? b.at[1] : 0;
                return ax !== bx ? ax - bx : ay - by;
            });
            floating.sort(function(a, b) {
                return (b.focusHistoryID || 99) - (a.focusHistoryID || 99);
            });
            return tiled.concat(floating);
        }

        // 2. Build and execute batch
        let batch = [];
        const TEMP_WS = 9999;
        let orderedA = sortedForMove(winsA);
        let orderedB = sortedForMove(winsB);

        // Move wsA -> TEMP
        for (let i = 0; i < orderedA.length; i++) {
            if (orderedA[i].address) {
                batch.push("dispatch hl.dsp.window.move({ workspace = " + TEMP_WS + ", follow = false, window = 'address:" + orderedA[i].address + "' })");
            }
        }
        // Swap layout rules if they differ
        if (layoutA && layoutB && layoutA !== layoutB) {
            batch.push("eval hl.workspace_rule({ workspace = '" + wsA + "', layout = '" + layoutB + "' })");
            batch.push("eval hl.workspace_rule({ workspace = '" + wsB + "', layout = '" + layoutA + "' })");
        }
        // Move wsB -> wsA (in spatial order so tiling layout is preserved)
        for (let i = 0; i < orderedB.length; i++) {
            if (orderedB[i].address) {
                batch.push("dispatch hl.dsp.window.move({ workspace = " + wsA + ", follow = false, window = 'address:" + orderedB[i].address + "' })");
            }
        }
        // Move TEMP -> wsB (in spatial order)
        for (let i = 0; i < orderedA.length; i++) {
            if (orderedA[i].address) {
                batch.push("dispatch hl.dsp.window.move({ workspace = " + wsB + ", follow = false, window = 'address:" + orderedA[i].address + "' })");
            }
        }

        if (batch.length > 0) {
            Quickshell.execDetached(["hyprctl", "--batch", batch.join(" ; ")]);
        }
        reSyncTimer.restart();
    }

    function closeWorkspace(wsId) {
        window.isDraggingWorkspace = false;
        window.draggedWorkspaceId = 0;
        if (!wsId) return;

        let wins = [];

        // Instant optimistic UI update
        if (window.workspacesData && window.workspacesData.length > 0) {
            let idx = window.workspacesData.findIndex(function(w) { return w.id === wsId; });
            if (idx !== -1) {
                let data = window.workspacesData.slice();
                let item = Object.assign({}, data[idx]);
                wins = item.windows ? item.windows.slice() : [];
                item.windows = [];
                item.isOccupied = false;
                data[idx] = item;
                window.workspacesData = data;
            }
        }

        // Dispatch window close directly to Hyprland in batch
        let batch = [];
        for (let i = 0; i < wins.length; i++) {
            if (wins[i].address) {
                batch.push("dispatch hl.dsp.focus({ window = 'address:" + wins[i].address + "' }) ; dispatch hl.dsp.window.close()");
            }
        }
        if (batch.length > 0) {
            Quickshell.execDetached(["hyprctl", "--batch", batch.join(" ; ")]);
        }
        reSyncTimer.restart();
    }

    function closeOverview() {
        window.draggedWorkspaceId = 0;
        window.isDraggingWorkspace = false;
        window.isDragging = false;
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    Keys.onEscapePressed: {
        closeOverview();
        event.accepted = true;
    }

    Keys.onLeftPressed: {
        window.isUserSelecting = true;
        if (window.workspacesData.length > 0) {
            let cur = (window.selectedIndex >= 0) ? window.selectedIndex : 0;
            window.selectedIndex = (cur > 0) ? cur - 1 : window.workspacesData.length - 1;
        }
        event.accepted = true;
    }

    Keys.onRightPressed: {
        window.isUserSelecting = true;
        if (window.workspacesData.length > 0) {
            let cur = (window.selectedIndex >= 0) ? window.selectedIndex : 0;
            window.selectedIndex = (cur < window.workspacesData.length - 1) ? cur + 1 : 0;
        }
        event.accepted = true;
    }

    Keys.onUpPressed: {
        window.isUserSelecting = true;
        let cols = 4;
        if (window.workspacesData.length > 0) {
            let cur = (window.selectedIndex >= 0) ? window.selectedIndex : 0;
            if (cur - cols >= 0) {
                window.selectedIndex = cur - cols;
            }
        }
        event.accepted = true;
    }

    Keys.onDownPressed: {
        window.isUserSelecting = true;
        let cols = 4;
        if (window.workspacesData.length > 0) {
            let cur = (window.selectedIndex >= 0) ? window.selectedIndex : 0;
            if (cur + cols < window.workspacesData.length) {
                window.selectedIndex = cur + cols;
            }
        }
        event.accepted = true;
    }

    Keys.onReturnPressed: {
        if (window.selectedIndex >= 0 && window.selectedIndex < window.workspacesData.length) {
            window.focusWorkspace(window.workspacesData[window.selectedIndex].id);
        }
        event.accepted = true;
    }

    Keys.onEnterPressed: {
        if (window.selectedIndex >= 0 && window.selectedIndex < window.workspacesData.length) {
            window.focusWorkspace(window.workspacesData[window.selectedIndex].id);
        }
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
                    model: window.workspaceCount

                    delegate: Rectangle {
                        id: wsCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(wsCard.width / window.monocleRatio)

                        readonly property int wsId: index + 1
                        readonly property var wsData: (window.workspacesData && index < window.workspacesData.length) ? window.workspacesData[index] : null
                        readonly property bool isActive: wsData ? Boolean(wsData.isActive) : (wsId === window.activeWorkspaceId)
                        readonly property bool isOccupied: wsData ? Boolean(wsData.isOccupied) : false
                        readonly property bool isSelected: index === window.selectedIndex
                        readonly property var windowsList: (wsData && wsData.windows) ? wsData.windows : []
                        property bool isHoveredDrop: false
                        property bool isHoveredWsDrop: false

                        // Elevate source workspace z-index when dragging so dragged window or workspace floats ABOVE all other workspace cards!
                        z: (window.draggedFromWs === wsId || window.draggedWorkspaceId === wsId) ? 9999 : 1

                        radius: window.s(12)
                        color: isHoveredWsDrop ? Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.75)
                                               : (isHoveredDrop ? Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.65) 
                                                                : (isSelected ? Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.55)
                                                                              : (wsCardMa.containsMouse ? Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.55) 
                                                                                                        : Qt.rgba(window.mantle.r, window.mantle.g, window.mantle.b, 0.25))))
                        border.color: isHoveredWsDrop ? window.mauve : (isHoveredDrop ? window.green : (isSelected ? window.mauve : (isActive ? Qt.rgba(window.blue.r, window.blue.g, window.blue.b, 0.7) : (wsCardMa.containsMouse ? window.surface2 : Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.3)))))
                        border.width: (isSelected || isHoveredDrop || isHoveredWsDrop) ? 2 : 1

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        // Background MouseArea for workspace selection
                        MouseArea {
                            id: wsCardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: (mouse) => {
                                window.isUserSelecting = true;
                                window.selectedIndex = index;
                            }
                            onClicked: {
                                window.focusWorkspace(wsCard.wsId);
                            }
                        }

                        // DropArea for receiving window drops and workspace drops
                        DropArea {
                            id: wsDropArea
                            anchors.fill: parent
                            z: 50
                            keys: ["window-card", "workspace-card"]

                            onEntered: (drag) => {
                                if (drag.keys.indexOf("workspace-card") !== -1) {
                                    let srcWs = (drag.source && drag.source.sourceWsId) ? drag.source.sourceWsId : window.draggedWorkspaceId;
                                    if (srcWs > 0 && srcWs !== wsCard.wsId) {
                                        wsCard.isHoveredWsDrop = true;
                                    }
                                } else if (drag.keys.indexOf("window-card") !== -1) {
                                    let fromWs = (drag.source && drag.source.winSourceWs) ? drag.source.winSourceWs : window.draggedFromWs;
                                    if (fromWs !== wsCard.wsId) {
                                        wsCard.isHoveredDrop = true;
                                    }
                                }
                            }

                            onExited: {
                                wsCard.isHoveredWsDrop = false;
                                wsCard.isHoveredDrop = false;
                            }

                            onDropped: (drop) => {
                                let wasWsDrop = wsCard.isHoveredWsDrop;
                                let wasWinDrop = wsCard.isHoveredDrop;
                                wsCard.isHoveredWsDrop = false;
                                wsCard.isHoveredDrop = false;

                                if (drop.keys.indexOf("workspace-card") !== -1 || wasWsDrop) {
                                    let srcWs = (drop.source && drop.source.sourceWsId) ? drop.source.sourceWsId : window.draggedWorkspaceId;
                                    window.isDraggingWorkspace = false;
                                    window.draggedWorkspaceId = 0;
                                    if (srcWs > 0 && srcWs !== wsCard.wsId) {
                                        window.swapWorkspaces(srcWs, wsCard.wsId);
                                        drop.accept();
                                    }
                                } else if (drop.keys.indexOf("window-card") !== -1 || wasWinDrop) {
                                    let addr = (drop.source && drop.source.winAddress) ? drop.source.winAddress : window.draggedWindowAddress;
                                    let fromWs = (drop.source && drop.source.winSourceWs) ? drop.source.winSourceWs : window.draggedFromWs;
                                    window.isDragging = false;
                                    window.draggedWindowAddress = "";
                                    window.draggedFromWs = 0;
                                    if (addr !== "" && wsCard.wsId !== fromWs) {
                                        window.moveWindowToWorkspace(addr, wsCard.wsId);
                                        drop.accept();
                                    }
                                }
                            }
                        }

                        // WORKSPACE HEADER & DRAG HANDLE
                        Rectangle {
                            id: wsHeader
                            anchors.top: parent.top
                            anchors.topMargin: window.s(4)
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: window.s(16)
                            color: "transparent"
                            z: 10

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: window.s(10)
                                anchors.rightMargin: window.s(10)

                                // Workspace number on the left (unhighlighted)
                                Text {
                                    text: wsCard.wsId.toString()
                                    font.family: "SF Pro Display"
                                    font.pixelSize: window.s(11)
                                    font.weight: Font.DemiBold
                                    color: window.subtext0
                                }

                                Item { Layout.fillWidth: true }
                            }

                            MouseArea {
                                id: wsHeaderMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: window.isDraggingWorkspace ? Qt.ClosedHandCursor : (containsMouse ? Qt.OpenHandCursor : Qt.PointingHandCursor)

                                drag.target: wsDragProxy
                                drag.axis: Drag.XAndYAxis

                                onPressed: (mouse) => {
                                    let pt = wsHeaderMa.mapToItem(mainCard, mouse.x, mouse.y);
                                    wsDragProxy.x = pt.x - wsDragProxy.width / 2;
                                    wsDragProxy.y = pt.y - wsDragProxy.height / 2;
                                    wsDragProxy.sourceWsId = wsCard.wsId;
                                    window.draggedWorkspaceId = wsCard.wsId;
                                    window.isDraggingWorkspace = true;
                                }

                                onReleased: (mouse) => {
                                    if (wsDragProxy.Drag.active) {
                                        wsDragProxy.Drag.drop();
                                    }
                                    window.draggedWorkspaceId = 0;
                                    window.isDraggingWorkspace = false;
                                }

                                onCanceled: {
                                    window.draggedWorkspaceId = 0;
                                    window.isDraggingWorkspace = false;
                                }

                                onClicked: (mouse) => {
                                    window.focusWorkspace(wsCard.wsId);
                                }
                            }
                        }

                        // Background Workspace Number Display
                        Text {
                            anchors.centerIn: viewport
                            text: wsCard.wsId.toString()
                            font.family: "SF Pro Display"
                            font.pixelSize: window.s(54)
                            font.weight: Font.Black
                            color: wsCard.isActive ? window.mauve : window.text
                            opacity: wsCard.isActive ? 0.22 : 0.08
                            z: 0
                        }

                        // Hovered Swap Overlay Indicator
                        Rectangle {
                            anchors.centerIn: parent
                            width: swapRow.implicitWidth + window.s(20)
                            height: window.s(28)
                            radius: window.s(14)
                            color: Qt.rgba(window.mauve.r, window.mauve.g, window.mauve.b, 0.95)
                            border.color: window.text
                            border.width: 1
                            visible: wsCard.isHoveredWsDrop
                            z: 200

                            RowLayout {
                                id: swapRow
                                anchors.centerIn: parent
                                spacing: window.s(6)
                                Text {
                                    text: "⇄"
                                    font.pixelSize: window.s(14)
                                    font.bold: true
                                    color: window.crust
                                }
                                Text {
                                    text: "Swap with Workspace " + window.draggedWorkspaceId
                                    font.family: "SF Pro Text"
                                    font.pixelSize: window.s(11)
                                    font.weight: Font.Bold
                                    color: window.crust
                                }
                            }
                        }

                        // MONITOR VIEWPORT
                        Rectangle {
                            id: viewport
                            anchors.top: wsHeader.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: window.s(3)
                            radius: window.s(8)
                            color: "transparent"
                            clip: !(window.isDragging && window.draggedFromWs === wsCard.wsId)
                            z: 1

                            Repeater {
                                model: wsCard.windowsList

                                delegate: Item {
                                    id: winContainer

                                    readonly property var winData: modelData
                                    property string winAddress: winData.address || ""
                                    property int winSourceWs: wsCard.wsId
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

                                    Drag.active: window.isDragging && window.draggedWindowAddress === winAddress
                                    Drag.keys: ["window-card"]
                                    Drag.source: winContainer
                                    Drag.onDragFinished: {
                                        window.draggedWindowAddress = "";
                                        window.draggedFromWs = 0;
                                        window.isDragging = false;
                                    }

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

                                        // Live Screencopy Background Preview (Aspect-Crop to Fill Container)
                                        Item {
                                            id: scCropWrapper
                                            anchors.fill: parent
                                            clip: true
                                            visible: scView.hasContent

                                            readonly property real srcRatio: window.monocleRatio

                                            readonly property real containerRatio: (winMiniCard.width / Math.max(1, winMiniCard.height))

                                            ScreencopyView {
                                                id: scView
                                                width: (scCropWrapper.srcRatio > scCropWrapper.containerRatio) ? (winMiniCard.height * scCropWrapper.srcRatio) : winMiniCard.width
                                                height: (scCropWrapper.srcRatio > scCropWrapper.containerRatio) ? winMiniCard.height : (winMiniCard.width / scCropWrapper.srcRatio)
                                                anchors.centerIn: parent

                                                captureSource: window.getToplevelForAddress(winData.address)
                                                live: window.visible
                                                paintCursor: false
                                            }

                                            // Readability Overlay
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: window.s(6)
                                                color: Qt.rgba(0, 0, 0, 0.35)
                                            }
                                        }


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
                                                onStatusChanged: {
                                                    if (status === Image.Error && source.toString() !== "image://icon/application-x-executable") {
                                                        source = "image://icon/application-x-executable";
                                                    }
                                                }
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

                                                winContainer.winAddress = winData.address || "";
                                                winContainer.winSourceWs = wsCard.wsId;
                                                window.draggedWindowAddress = winData.address || "";
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

                                            onCanceled: {
                                                window.draggedWindowAddress = "";
                                                window.draggedFromWs = 0;
                                                window.isDragging = false;
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
            // TRASHCAN DROP ZONE FOR CLOSING WINDOWS OR WORKSPACES
            // -----------------------------------------------------------------
            Rectangle {
                id: trashZone
                Layout.fillWidth: true
                Layout.preferredHeight: window.s(36)
                radius: window.s(10)
                color: (window.isOverTrash || window.isOverTrashWs) ? window.red : Qt.rgba(window.mantle.r, window.mantle.g, window.mantle.b, 0.3)
                border.color: (window.isOverTrash || window.isOverTrashWs) ? window.red : Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.4)
                border.width: (window.isOverTrash || window.isOverTrashWs) ? 2 : 1

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                DropArea {
                    anchors.fill: parent
                    keys: ["window-card", "workspace-card"]

                    onEntered: (drag) => {
                        if (drag.keys.indexOf("workspace-card") !== -1) {
                            window.isOverTrashWs = true;
                        } else {
                            window.isOverTrash = true;
                        }
                    }

                    onExited: {
                        window.isOverTrashWs = false;
                        window.isOverTrash = false;
                    }

                    onDropped: (drop) => {
                        let wasWs = window.isOverTrashWs;
                        let wasWin = window.isOverTrash;
                        window.isOverTrashWs = false;
                        window.isOverTrash = false;

                        if (drop.keys.indexOf("workspace-card") !== -1 || wasWs) {
                            let wsId = (drop.source && drop.source.sourceWsId) ? drop.source.sourceWsId : window.draggedWorkspaceId;
                            window.isDraggingWorkspace = false;
                            window.draggedWorkspaceId = 0;
                            if (wsId > 0) {
                                window.closeWorkspace(wsId);
                                drop.accept();
                            }
                        } else if (drop.keys.indexOf("window-card") !== -1 || wasWin) {
                            let addr = (drop.source && drop.source.winAddress) ? drop.source.winAddress : window.draggedWindowAddress;
                            window.isDragging = false;
                            window.draggedWindowAddress = "";
                            window.draggedFromWs = 0;
                            if (addr !== "") {
                                window.closeWindow(addr);
                                drop.accept();
                            }
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
                        text: window.isOverTrashWs
                              ? ("Release to Close Workspace " + window.draggedWorkspaceId + " (All Windows)")
                              : (window.isOverTrash ? "Release to Close Window" : "Drag window or workspace here to close")
                        font.family: "SF Pro Text"
                        font.pixelSize: window.s(11)
                        font.weight: (window.isOverTrash || window.isOverTrashWs) ? Font.Bold : Font.Medium
                        color: (window.isOverTrash || window.isOverTrashWs) ? window.crust : window.subtext0
                    }
                }
            }
        }

        // Safety release catcher: dismiss ghost if released anywhere outside drop areas
        MouseArea {
            anchors.fill: parent
            z: (window.isDraggingWorkspace || window.isDragging) ? 99990 : -1
            enabled: window.isDraggingWorkspace || window.isDragging
            onClicked: {
                window.draggedWorkspaceId = 0;
                window.isDraggingWorkspace = false;
                window.draggedWindowAddress = "";
                window.draggedFromWs = 0;
                window.isDragging = false;
            }
            onReleased: {
                window.draggedWorkspaceId = 0;
                window.isDraggingWorkspace = false;
                window.draggedWindowAddress = "";
                window.draggedFromWs = 0;
                window.isDragging = false;
            }
        }

        // ---------------------------------------------------------------------
        // FLOATING GHOST PREVIEW FOR WORKSPACE DRAGGING
        // ---------------------------------------------------------------------
        Item {
            id: wsDragProxy
            width: window.s(180)
            height: Math.round(width / window.monocleRatio)
            visible: window.isDraggingWorkspace && window.draggedWorkspaceId > 0
            z: 99999

            property int sourceWsId: 0

            Drag.active: window.isDraggingWorkspace
            Drag.keys: ["workspace-card"]
            Drag.source: wsDragProxy
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            Drag.onDragFinished: {
                window.draggedWorkspaceId = 0;
                window.isDraggingWorkspace = false;
            }

            Rectangle {
                anchors.fill: parent
                radius: window.s(10)
                color: Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.92)
                border.color: window.mauve
                border.width: 2

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: window.s(4)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Workspace " + window.draggedWorkspaceId
                        font.family: "SF Pro Display"
                        font.pixelSize: window.s(14)
                        font.weight: Font.Bold
                        color: window.mauve
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "⇄ Drag to Swap or 🗑️ Close"
                        font.family: "SF Pro Text"
                        font.pixelSize: window.s(10)
                        color: window.subtext0
                    }
                }
            }
        }
    }
}
