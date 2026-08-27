import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: barWindow
            property bool pendingReload: false
            
	    Caching { id: paths }

	    Component.onCompleted: {
 	        console.log("runDir:", paths.runDir)
 	        console.log("manual path:", paths.runDir + "/workspaces")
 	        console.log("env test:", Quickshell.env("QS_RUN_WORKSPACES"))
 	        console.log("wsPath:", paths.getRunDir("workspaces"))
	    }	     	
        
            IpcHandler {
                target: "topbar"
                function forceReload() {
                    Quickshell.reload(true) 
                }
                function queueReload() {
                    if (!barWindow.isSettingsOpen) {
                        Quickshell.reload(true)
                    } else {
                        barWindow.pendingReload = true
                    }
                }
                function toggleUpdate() {
                    barWindow.forceUpdateShow = !barWindow.forceUpdateShow
                }
            }

            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "qs-topbar"
            WlrLayershell.layer: WlrLayer.Overlay

            anchors {
                top: true
                left: true
                right: true
            }

            Scaler {
                id: scaler
                currentWidth: barWindow.width
            }

            property real baseScale: scaler.baseScale

            function s(val) { 
                return scaler.s(val); 
            }

            property int barHeight: s(44)

            implicitHeight: barHeight + s(16)
            margins { top: 0; bottom: 0; left: 0; right: 0 }
            
            property var hyprMon: Hyprland.monitorFor(barWindow.screen)
            property bool isWindowFullscreen: (hyprMon && hyprMon.activeWorkspace) ? hyprMon.activeWorkspace.hasFullscreen : false

            onIsWindowFullscreenChanged: {
                if (!isWindowFullscreen) {
                    isLeftRevealed = false;
                    isCenterRevealed = false;
                    isRightRevealed = false;
                }
            }
            property bool isLeftRevealed: false
            property bool isCenterRevealed: false
            property bool isRightRevealed: false
            
            property string activeWidget: "" 
            property bool isSettingsOpen: activeWidget === "settings"

            readonly property bool isLeftWidgetOpen: isSettingsOpen || activeWidget === "guide" || activeWidget === "help" || activeWidget === "applauncher" || activeWidget === "search" || activeWidget === "updater"
            readonly property bool isCenterWidgetOpen: activeWidget === "music" || activeWidget === "calendar"
            readonly property bool isRightWidgetOpen: activeWidget === "network" || activeWidget === "volume" || activeWidget === "monitors" || activeWidget === "notifications" || activeWidget === "battery" || activeWidget === "hardware"

            readonly property bool isLeftHidden: isWindowFullscreen && !isLeftRevealed && !isLeftWidgetOpen
            readonly property bool isCenterHidden: isWindowFullscreen && !isCenterRevealed && !isCenterWidgetOpen
            readonly property bool isRightHidden: isWindowFullscreen && !isRightRevealed && !isRightWidgetOpen

            exclusionMode: isWindowFullscreen ? ExclusionMode.Ignore : ExclusionMode.Normal
            exclusiveZone: isWindowFullscreen ? 0 : barHeight
            color: "transparent"

            mask: Region {
                Region {
                    x: 0; y: 0
                    width: !barWindow.isWindowFullscreen ? barWindow.width : 0
                    height: !barWindow.isWindowFullscreen ? barWindow.height : 0
                }

                Region {
                    x: 0; y: 0
                    width: barWindow.isWindowFullscreen ? Math.floor(barWindow.width / 3) : 0
                    height: barWindow.isWindowFullscreen ? barWindow.s(6) : 0
                }
                Region {
                    x: barWindow.isWindowFullscreen ? Math.floor(barWindow.width / 3) : 0
                    y: 0
                    width: barWindow.isWindowFullscreen ? Math.floor(barWindow.width / 3) : 0
                    height: barWindow.isWindowFullscreen ? barWindow.s(6) : 0
                }
                Region {
                    x: barWindow.isWindowFullscreen ? Math.floor(barWindow.width * 2 / 3) : 0
                    y: 0
                    width: barWindow.isWindowFullscreen ? (barWindow.width - Math.floor(barWindow.width * 2 / 3)) : 0
                    height: barWindow.isWindowFullscreen ? barWindow.s(6) : 0
                }

                Region {
                    x: (barWindow.isWindowFullscreen && (barWindow.isLeftRevealed || barWindow.isLeftWidgetOpen)) ? Math.max(0, leftBox.x - barWindow.s(10)) : 0
                    y: (barWindow.isWindowFullscreen && (barWindow.isLeftRevealed || barWindow.isLeftWidgetOpen)) ? 0 : 0
                    width: (barWindow.isWindowFullscreen && (barWindow.isLeftRevealed || barWindow.isLeftWidgetOpen)) ? (leftBox.width + barWindow.s(20)) : 0
                    height: (barWindow.isWindowFullscreen && (barWindow.isLeftRevealed || barWindow.isLeftWidgetOpen)) ? (barWindow.barHeight + barWindow.s(16)) : 0
                }
                Region {
                    x: (barWindow.isWindowFullscreen && (barWindow.isCenterRevealed || barWindow.isCenterWidgetOpen)) ? Math.max(0, centerBox.x - barWindow.s(10)) : 0
                    y: (barWindow.isWindowFullscreen && (barWindow.isCenterRevealed || barWindow.isCenterWidgetOpen)) ? 0 : 0
                    width: (barWindow.isWindowFullscreen && (barWindow.isCenterRevealed || barWindow.isCenterWidgetOpen)) ? (centerBox.width + barWindow.s(20)) : 0
                    height: (barWindow.isWindowFullscreen && (barWindow.isCenterRevealed || barWindow.isCenterWidgetOpen)) ? (barWindow.barHeight + barWindow.s(16)) : 0
                }
                Region {
                    x: (barWindow.isWindowFullscreen && (barWindow.isRightRevealed || barWindow.isRightWidgetOpen)) ? Math.max(0, rightBox.x - barWindow.s(10)) : 0
                    y: (barWindow.isWindowFullscreen && (barWindow.isRightRevealed || barWindow.isRightWidgetOpen)) ? 0 : 0
                    width: (barWindow.isWindowFullscreen && (barWindow.isRightRevealed || barWindow.isRightWidgetOpen)) ? (rightBox.width + barWindow.s(20)) : 0
                    height: (barWindow.isWindowFullscreen && (barWindow.isRightRevealed || barWindow.isRightWidgetOpen)) ? (barWindow.barHeight + barWindow.s(16)) : 0
                }
            }



            property bool useLeftGraceTimer: false
            property bool useCenterGraceTimer: false
            property bool useRightGraceTimer: false

            function isLeftHovered() {
                return (typeof leftHoverTracker !== "undefined" && leftHoverTracker.hovered) ||
                       (typeof leftEdgeTrigger !== "undefined" && leftEdgeTrigger.containsMouse) ||
                       (typeof leftBoxDragArea !== "undefined" && (leftBoxDragArea.containsMouse || leftBoxDragArea.pressed));
            }

            function isCenterHovered() {
                return (typeof centerHoverTracker !== "undefined" && centerHoverTracker.hovered) ||
                       (typeof centerEdgeTrigger !== "undefined" && centerEdgeTrigger.containsMouse) ||
                       (typeof centerBoxDragArea !== "undefined" && (centerBoxDragArea.containsMouse || centerBoxDragArea.pressed));
            }

            function isRightHovered() {
                return (typeof rightHoverTracker !== "undefined" && rightHoverTracker.hovered) ||
                       (typeof rightEdgeTrigger !== "undefined" && rightEdgeTrigger.containsMouse) ||
                       (typeof rightBoxDragArea !== "undefined" && (rightBoxDragArea.containsMouse || rightBoxDragArea.pressed));
            }

            function kickLeftTimer() {
                if (isLeftHovered()) return;
                leftHideTimer.restart();
            }

            function kickCenterTimer() {
                if (isCenterHovered()) return;
                centerHideTimer.restart();
            }

            function kickRightTimer() {
                if (isRightHovered()) return;
                rightHideTimer.restart();
            }

            onIsLeftWidgetOpenChanged: {
                if (!isLeftWidgetOpen) {
                    if (!isLeftHovered()) {
                        barWindow.isLeftRevealed = false;
                    } else {
                        kickLeftTimer();
                    }
                }
            }

            onIsCenterWidgetOpenChanged: {
                if (!isCenterWidgetOpen) {
                    if (!isCenterHovered()) {
                        barWindow.isCenterRevealed = false;
                    } else {
                        kickCenterTimer();
                    }
                }
            }

            onIsRightWidgetOpenChanged: {
                if (!isRightWidgetOpen) {
                    if (!isRightHovered()) {
                        barWindow.isRightRevealed = false;
                    } else {
                        kickRightTimer();
                    }
                }
            }

            Timer { id: leftShowTimer; interval: 0; onTriggered: barWindow.isLeftRevealed = true }
            Timer { id: centerShowTimer; interval: 0; onTriggered: barWindow.isCenterRevealed = true }
            Timer { id: rightShowTimer; interval: 0; onTriggered: barWindow.isRightRevealed = true }

            Timer {
                id: leftHideTimer
                interval: barWindow.useLeftGraceTimer ? 3000 : 800
                onTriggered: {
                    if (barWindow.isLeftHovered() || barWindow.isLeftWidgetOpen) {
                        return;
                    }
                    barWindow.isLeftRevealed = false;
                    barWindow.useLeftGraceTimer = false;
                }
            }
            Timer {
                id: centerHideTimer
                interval: barWindow.useCenterGraceTimer ? 3000 : 800
                onTriggered: {
                    if (barWindow.isCenterHovered() || barWindow.isCenterWidgetOpen) {
                        return;
                    }
                    barWindow.isCenterRevealed = false;
                    barWindow.useCenterGraceTimer = false;
                }
            }
            Timer {
                id: rightHideTimer
                interval: barWindow.useRightGraceTimer ? 3000 : 800
                onTriggered: {
                    if (barWindow.isRightHovered() || barWindow.isRightWidgetOpen) {
                        return;
                    }
                    barWindow.isRightRevealed = false;
                    barWindow.useRightGraceTimer = false;
                }
            }

            MatugenColors {
                id: mocha
            }

            property bool showHelpIcon: true
            property bool isRecording: false
            
            property bool updateAvailable: false
            property bool forceUpdateShow: false
            property bool isUpdateVisible: updateAvailable || forceUpdateShow
            
            property int workspaceCount: 8
            
            property bool hasHwFeatures: false
            property bool isHwTurboOn: false

            property real settingsSlideProgress: isSettingsOpen ? 1.0 : 0.0
            Behavior on settingsSlideProgress { 
                enabled: barWindow.startupCascadeFinished
                NumberAnimation { duration: 600; easing.type: Easing.OutExpo } 
            }

            onIsSettingsOpenChanged: {
                if (!barWindow.isSettingsOpen && barWindow.pendingReload) {
                    barWindow.pendingReload = false;
                    Quickshell.reload(true);
                }
            }

            Process {
                id: widgetPoller
                command: ["bash", "-c", "cat " + paths.runDir + "/current_widget 2>/dev/null || echo ''"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (barWindow.activeWidget !== txt) barWindow.activeWidget = txt;
                    }
                }
            }

            Process {
                id: widgetWatcher
                command: ["bash", "-c", "while [ ! -f " + paths.runDir + "/current_widget ]; do sleep 1; done; inotifywait -qq -e modify,close_write " + paths.runDir + "/current_widget"]
                running: true
                onExited: {
                    widgetPoller.running = false;
                    widgetPoller.running = true;
                    running = false;
                    running = true;
                }
            }
            
            Process {
                id: recPoller
                command: ["bash", "-c", "if [ -s " + paths.getCacheDir("recording") + "/rec_pid ] && kill -0 $(cat " + paths.getCacheDir("recording") + "/rec_pid) 2>/dev/null; then echo '1'; else echo '0'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isRecording = (this.text.trim() === "1");
                    }
                }
            }

            Process {
 	    	id: recWatcher
 		running: true
 		command: ["bash", "-c", "inotifywait -qq -e create,delete,modify,close_write " + paths.getCacheDir("recording") + "/ 2>/dev/null || sleep 2"]
 	        onExited: {
 	        	recPoller.running = false;
 	         	recPoller.running = true;
 	         	running = false;
 	         	running = true;
 	        }
	    }	  
            Process {
	        id: updatePoller
	        command: ["bash", "-c", "if [ -f " + paths.getCacheDir("updater") + "/update_pending ]; then echo '1'; else echo '0'; fi"]
	        running: true
	        stdout: StdioCollector {
	            onStreamFinished: {
	                barWindow.updateAvailable = (this.text.trim() === "1");
	            }
	        }
	    }
	    
	    Process {
	        id: updateWatcher
	        running: true
	        command: ["bash", "-c", "inotifywait -qq -e create,delete,close_write " + paths.getCacheDir("updater") + "/ 2>/dev/null || sleep 5"]
	        onExited: {
	            updatePoller.running = false;
	            updatePoller.running = true;
	            running = false;
	            running = true;
	        }
	    }
	                
            Process {
                id: settingsReader
                command: ["bash", "-c", "cat ~/.config/hypr/settings.json 2>/dev/null || echo '{}'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            if (this.text && this.text.trim().length > 0 && this.text.trim() !== "{}") {
                                let parsed = JSON.parse(this.text);
                                
                                if (parsed.topbarHelpIcon !== undefined && barWindow.showHelpIcon !== parsed.topbarHelpIcon) {
                                    barWindow.showHelpIcon = parsed.topbarHelpIcon;
                                }
                                
                                if (parsed.workspaceCount !== undefined && barWindow.workspaceCount !== parsed.workspaceCount) {
                                    barWindow.workspaceCount = parsed.workspaceCount;
                                    wsDaemon.running = false;
                                    wsDaemon.running = true;
                                }
                            }
                        } catch (e) {}
                    }
                }
            }

            Process {
                id: settingsWatcher
                command: ["bash", "-c", "while [ ! -f ~/.config/hypr/settings.json ]; do sleep 1; done; inotifywait -qq -e modify,close_write ~/.config/hypr/settings.json"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        settingsReader.running = false;
                        settingsReader.running = true;
                        
                        settingsWatcher.running = false;
                        settingsWatcher.running = true;
                    }
                }
            }
            
            property bool isDesktop: false
            property string ethStatus: "Ethernet"

            Process {
                id: chassisDetector
                running: true
                command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isDesktop = (this.text.trim() === "desktop");
                    }
                }
            }

            property bool isStartupReady: false
            Timer { interval: 10; running: true; onTriggered: barWindow.isStartupReady = true }
            
            property bool startupCascadeFinished: false
            Timer { interval: 1000; running: true; onTriggered: barWindow.startupCascadeFinished = true }
            
            property bool fastPollerLoaded: false
            property bool isDataReady: fastPollerLoaded
            Timer { interval: 600; running: true; onTriggered: barWindow.isDataReady = true }
            
            property string timeStr: ""
            property string fullDateStr: ""
            property int typeInIndex: 0
            property string dateStr: fullDateStr.substring(0, typeInIndex)

            property string weatherIcon: ""
            property string weatherTemp: "--°"
            property string weatherHex: mocha.yellow
            
            property string wifiStatus: "Off"
            property string wifiIcon: "󰤮"
            property string wifiSsid: ""
            
            property string btStatus: "Off"
            property string btIcon: "󰂲"
            property string btDevice: ""
            
            property string volPercent: "0%"
            property string volIcon: "󰕾"
            property bool isMuted: false
            
            property string batPercent: "100%"
            property string batIcon: "󰁹"
            property string batStatus: "Unknown"
            
            property string kbLayout: "us"
            
            ListModel { 
                id: workspacesModel 
                property int activeIndex: 0
            }
            
            property var musicData: { "status": "Stopped", "title": "", "artUrl": "", "timeStr": "" }

            property string displayTitle: ""
            property string displayTime: ""
            property string displayArtUrl: ""

            onMusicDataChanged: {
                if (musicData && musicData.status !== "Stopped" && musicData.title !== "") {
                    displayTitle = musicData.title;
                    displayTime = musicData.timeStr;
                    displayArtUrl = musicData.artUrl;
                }
            }

            property bool isMediaActive: barWindow.musicData.status !== "Stopped" && barWindow.musicData.title !== ""
            property bool isWifiOn: barWindow.wifiStatus.toLowerCase() === "enabled" || barWindow.wifiStatus.toLowerCase() === "on"
            property bool isBtOn: barWindow.btStatus.toLowerCase() === "enabled" || barWindow.btStatus.toLowerCase() === "on"
            property bool showEthernet: barWindow.ethStatus === "Connected" || (barWindow.isDesktop && !barWindow.isWifiOn)
            
            property bool isSoundActive: !barWindow.isMuted && parseInt(barWindow.volPercent) > 0
            property int batCap: parseInt(barWindow.batPercent) || 0
            property bool isCharging: barWindow.batStatus === "Charging" || barWindow.batStatus === "Full"
            
            property color batDynamicColor: {
                if (isCharging) return mocha.green;
                if (batCap <= 20) return mocha.red;
                return mocha.text; 
            }

            Process {
                id: wsDaemon
                command: ["bash", "-c", "~/.config/hypr/scripts/workspaces.sh"]
                running: true
            }

            Process {
		id: wsReader
		running: true
                command: ["cat", paths.getRunDir("workspaces") + "/workspaces.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { 
                                let newData = JSON.parse(txt);
                                
                                while (workspacesModel.count < newData.length) {
                                    workspacesModel.append({ "wsId": "", "wsState": "" });
                                }
                                
                                while (workspacesModel.count > newData.length) {
                                    workspacesModel.remove(workspacesModel.count - 1);
                                }
                                
                                let newActive = -1;

                                for (let i = 0; i < newData.length; i++) {
                                    if (newData[i].state === "active") newActive = i;

                                    if (workspacesModel.get(i).wsState !== newData[i].state) {
                                        workspacesModel.setProperty(i, "wsState", newData[i].state);
                                    }
                                    if (workspacesModel.get(i).wsId !== newData[i].id.toString()) {
                                        workspacesModel.setProperty(i, "wsId", newData[i].id.toString());
                                    }
                                }

                                if (newActive !== -1 && workspacesModel.activeIndex !== newActive) {
                                    workspacesModel.activeIndex = newActive;
                                }

                            } catch(e) {}
                        }
                    }
                }
            }

            Process {
                id: wsWatcher
                running: true
                command: ["bash", "-c", "inotifywait -qq -e close_write,modify " + paths.getRunDir("workspaces") + "/workspaces.json"]
                onExited: {
                    wsReader.running = false;
                    wsReader.running = true;
                    running = false;
                    running = true;
                }
            }

            Process {
                id: musicForceRefresh
                running: true
                command: ["bash", "-c", "bash ~/.config/hypr/scripts/quickshell/music/music_info.sh | tee " + paths.getRunDir("music") + "/music_info.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { barWindow.musicData = JSON.parse(txt); } catch(e) {}
                        }
                    }
                }
            }

            Timer {
                interval: 1000
                running: barWindow.musicData !== null && barWindow.musicData.status === "Playing"
                repeat: true
                onTriggered: {
                    if (!barWindow.musicData || barWindow.musicData.status !== "Playing") return;
                    if (!barWindow.musicData.timeStr || barWindow.musicData.timeStr === "") return;

                    let parts = barWindow.musicData.timeStr.split(" / ");
                    if (parts.length !== 2) return;

                    let posParts = parts[0].split(":").map(Number);
                    let lenParts = parts[1].split(":").map(Number);

                    let posSecs = (posParts.length === 3) 
                        ? (posParts[0] * 3600 + posParts[1] * 60 + posParts[2]) 
                        : (posParts[0] * 60 + posParts[1]);

                    let lenSecs = (lenParts.length === 3) 
                        ? (lenParts[0] * 3600 + lenParts[1] * 60 + lenParts[2]) 
                        : (lenParts[0] * 60 + lenParts[1]);

                    if (isNaN(posSecs) || isNaN(lenSecs)) return;

                    posSecs++;
                    if (posSecs > lenSecs) posSecs = lenSecs;

                    let newPosStr = "";
                    if (posParts.length === 3) {
                        let h = Math.floor(posSecs / 3600);
                        let m = Math.floor((posSecs % 3600) / 60);
                        let s = posSecs % 60;
                        newPosStr = h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    } else {
                        let m = Math.floor(posSecs / 60);
                        let s = posSecs % 60;
                        newPosStr = (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    }

                    let newData = Object.assign({}, barWindow.musicData);
                    newData.timeStr = newPosStr + " / " + parts[1];
                    newData.positionStr = newPosStr;
                    if (lenSecs > 0) newData.percent = (posSecs / lenSecs) * 100;
                    
                    barWindow.musicData = newData;
                }
            }

            Process {
                id: mprisWatcher
                running: true
                command: ["bash", "-c", "dbus-monitor --session \"type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.mpris.MediaPlayer2.Player'\" \"type='signal',interface='org.mpris.MediaPlayer2.Player',member='Seeked'\" 2>/dev/null | grep -m 1 'member=' > /dev/null || sleep 2"]
                onExited: {
                    musicForceRefresh.running = false;
                    musicForceRefresh.running = true;
                    running = false;
                    running = true;
                }
            }

            Timer {
                id: artRetryTimer
                interval: 500
                repeat: true
                running: barWindow.displayArtUrl && barWindow.displayArtUrl.indexOf("placeholder_blank.png") !== -1
                onTriggered: {
                    musicForceRefresh.running = false;
                    musicForceRefresh.running = true;
                }
            }

            Process {
                id: kbPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/kb_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "" && barWindow.kbLayout !== txt) barWindow.kbLayout = txt;
                        kbWaiter.running = false;
                        kbWaiter.running = true;
                        barWindow.fastPollerLoaded = true; 
                    }
                }
            }
            Process { id: kbWaiter; command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/kb_wait.sh"]; onExited: { kbPoller.running = false; kbPoller.running = true; } }

            Process {
                id: audioPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/audio_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                let newVol = data.volume.toString() + "%";
                                if (barWindow.volPercent !== newVol) barWindow.volPercent = newVol;
                                if (barWindow.volIcon !== data.icon) barWindow.volIcon = data.icon;
                                let newMuted = (data.is_muted === "true");
                                if (barWindow.isMuted !== newMuted) barWindow.isMuted = newMuted;
                            } catch(e) {}
                        }
                        audioWaiter.running = false;
                        audioWaiter.running = true;
                    }
                }
            }
            Process { id: audioWaiter; command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/audio_wait.sh"]; onExited: { audioPoller.running = false; audioPoller.running = true; } }

            Process {
                id: networkPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/network_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                if (barWindow.wifiStatus !== data.status) barWindow.wifiStatus = data.status;
                                if (barWindow.wifiIcon !== data.icon) barWindow.wifiIcon = data.icon;
                                if (barWindow.wifiSsid !== data.ssid) barWindow.wifiSsid = data.ssid;
                                if (barWindow.ethStatus !== data.eth_status) barWindow.ethStatus = data.eth_status;
                            } catch(e) {}
                        }
                        networkWaiter.running = false;
                        networkWaiter.running = true;
                    }
                }
            }
            Process { id: networkWaiter; command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/network_wait.sh"]; onExited: { networkPoller.running = false; networkPoller.running = true; } }

            Process {
                id: btPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/bt_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                if (barWindow.btStatus !== data.status) barWindow.btStatus = data.status;
                                if (barWindow.btIcon !== data.icon) barWindow.btIcon = data.icon;
                                if (barWindow.btDevice !== data.connected) barWindow.btDevice = data.connected;
                            } catch(e) {}
                        }
                        btWaiter.running = false;
                        btWaiter.running = true;
                    }
                }
            }
            Process { id: btWaiter; command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/bt_wait.sh"]; onExited: { btPoller.running = false; btPoller.running = true; } }

            Process {
                id: batteryPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/battery_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                let newBat = data.percent.toString() + "%";
                                if (barWindow.batPercent !== newBat) barWindow.batPercent = newBat;
                                if (barWindow.batIcon !== data.icon) barWindow.batIcon = data.icon;
                                if (barWindow.batStatus !== data.status) barWindow.batStatus = data.status;
                            } catch(e) {}
                        }
                        batteryWaiter.running = false;
                        batteryWaiter.running = true;
                    }
                }
            }
            Process { id: batteryWaiter; command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/battery_wait.sh"]; onExited: { batteryPoller.running = false; batteryPoller.running = true; } }

            Process {
                id: weatherPoller
                command: ["bash", "-c", `
                    echo "$(~/.config/hypr/scripts/quickshell/calendar/weather.sh --current-icon)"
                    echo "$(~/.config/hypr/scripts/quickshell/calendar/weather.sh --current-temp)"
                    echo "$(~/.config/hypr/scripts/quickshell/calendar/weather.sh --current-hex)"
                `]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let lines = this.text.trim().split("\n");
                        if (lines.length >= 3) {
                            barWindow.weatherIcon = lines[0];
                            barWindow.weatherTemp = lines[1];
                            barWindow.weatherHex = lines[2] || mocha.yellow;
                        }
                    }
                }
            }
            Timer { interval: 150000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { weatherPoller.running = false; weatherPoller.running = true; } }

            Process {
                id: hwPoller
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/hardware/hw_ctl.sh get 2>/dev/null || echo '{}'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            if (this.text && this.text.trim().length > 0) {
                                let d = JSON.parse(this.text);
                                barWindow.hasHwFeatures = (d.hasBatteryThreshold || d.hasTurbo);
                                barWindow.isHwTurboOn = (d.turbo === "on");
                            }
                        } catch(e) {}
                    }
                }
            }
            Timer { interval: 5000; running: true; repeat: true; onTriggered: { hwPoller.running = false; hwPoller.running = true; } }

            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let d = new Date();
                    barWindow.timeStr = Qt.formatDateTime(d, "HH:mm:ss");
                    barWindow.fullDateStr = Qt.formatDateTime(d, "dddd, MMMM dd");
                    if (barWindow.typeInIndex >= barWindow.fullDateStr.length) {
                        barWindow.typeInIndex = barWindow.fullDateStr.length;
                    }
                }
            }

            Timer {
                id: typewriterTimer
                interval: 40
                running: barWindow.isStartupReady && barWindow.typeInIndex < barWindow.fullDateStr.length
                repeat: true
                onTriggered: barWindow.typeInIndex += 1
            }

            // Edge Triggers for Fullscreen Autohide (Top 6 pixels, divided into left, center, and right thirds)
            MouseArea {
                id: leftEdgeTrigger
                x: 0
                y: 0
                width: Math.floor(parent.width / 3)
                height: barWindow.s(6)
                hoverEnabled: true
                z: 100
                enabled: barWindow.isWindowFullscreen
                onEntered: {
                    leftHideTimer.stop();
                    leftShowTimer.restart();
                }
                onExited: {
                    leftShowTimer.stop();
                    barWindow.kickLeftTimer();
                }
            }
            MouseArea {
                id: centerEdgeTrigger
                x: Math.floor(parent.width / 3)
                y: 0
                width: Math.floor(parent.width / 3)
                height: barWindow.s(6)
                hoverEnabled: true
                z: 100
                enabled: barWindow.isWindowFullscreen
                onEntered: {
                    centerHideTimer.stop();
                    centerShowTimer.restart();
                }
                onExited: {
                    centerShowTimer.stop();
                    barWindow.kickCenterTimer();
                }
            }
            MouseArea {
                id: rightEdgeTrigger
                x: Math.floor(parent.width * 2 / 3)
                y: 0
                width: parent.width - Math.floor(parent.width * 2 / 3)
                height: barWindow.s(6)
                hoverEnabled: true
                z: 100
                enabled: barWindow.isWindowFullscreen
                onEntered: {
                    rightHideTimer.stop();
                    rightShowTimer.restart();
                }
                onExited: {
                    rightShowTimer.stop();
                    barWindow.kickRightTimer();
                }
            }

            Item {
                id: barContainer
                anchors.fill: parent

                // =============================================================
                // --- 1. LEFT DYNAMIC ISLAND (Tools & Workspaces Unified) ---
                // =============================================================
                Item {
                    id: leftBox
                    y: 0
                    height: barWindow.barHeight
                    width: leftRow.implicitWidth + barWindow.s(22)
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }

                    HoverHandler {
                        id: leftHoverTracker
                        onHoveredChanged: {
                            if (hovered) {
                                barWindow.useLeftGraceTimer = false;
                                leftHideTimer.stop();
                            } else {
                                barWindow.kickLeftTimer();
                            }
                        }
                    }

                    MouseArea {
                        id: leftBoxDragArea
                        anchors.fill: parent
                        anchors.margins: -barWindow.s(6)
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        z: -1
                        onEntered: {
                            barWindow.useLeftGraceTimer = false;
                            leftHideTimer.stop();
                        }
                        onExited: barWindow.kickLeftTimer()
                    }

                    IslandBackground {
                        hasTopLeftEar: false
                        hasTopRightEar: true
                        hasBottomLeftEar: true
                        hasBottomLeftRadius: false
                        hasBottomRightRadius: true
                        earRadius: barWindow.s(14)
                        bottomRadius: barWindow.s(14)
                        fillColor: barWindow.isWindowFullscreen ? "#000000" : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        strokeColor: barWindow.isWindowFullscreen ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.15) : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
                        Behavior on fillColor { ColorAnimation { duration: 200 } }
                        Behavior on strokeColor { ColorAnimation { duration: 200 } }
                    }
                    
                    property bool showLayout: false
                    
                    opacity: barWindow.isLeftHidden ? 0.0 : ((showLayout && !barWindow.isSettingsOpen) ? 1 : 0)
                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    enabled: !barWindow.isSettingsOpen
                    
                    property real targetX: (showLayout && !barWindow.isSettingsOpen) ? 0 : barWindow.s(-400)
                    x: targetX
                    Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                    
                    transform: Translate {
                        x: barWindow.isLeftHidden ? -(leftBox.width + barWindow.s(20)) : 0
                        y: barWindow.isLeftHidden ? -(barWindow.barHeight + barWindow.s(20)) : 0
                        Behavior on x { NumberAnimation { duration: 300; easing.type: barWindow.isLeftHidden ? Easing.InCubic : Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 300; easing.type: barWindow.isLeftHidden ? Easing.InCubic : Easing.OutCubic } }
                    }
                    
                    
                    Timer {
                        running: barWindow.isStartupReady
                        interval: 10
                        onTriggered: leftBox.showLayout = true
                    }

                    Row {
                        id: leftRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: barWindow.s(10)
                        spacing: barWindow.s(8)
                        
                        property int pillHeight: barWindow.s(32)

                        // Tools Sub-Row
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: barWindow.s(4)

                            Rectangle {
                                property bool isHovered: helpMouse.containsMouse
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : "transparent"
                                radius: barWindow.s(10)
                                
                                property real targetWidth: barWindow.showHelpIcon ? barWindow.s(32) : 0
                                width: targetWidth
                                height: leftRow.pillHeight
                                visible: targetWidth > 0 || opacity > 0
                                opacity: barWindow.showHelpIcon ? 1.0 : 0.0
                                clip: true
                                
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰋗"
                                    font.family: "SF Pro "; font.pixelSize: barWindow.s(20)
                                    color: parent.isHovered ? mocha.teal : mocha.text
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    scale: parent.isHovered ? 1.15 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                }
                                MouseArea {
                                    id: helpMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle guide"])
                                }
                            }

                            Rectangle {
                                property bool isHovered: searchMouse.containsMouse
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : "transparent"
                                radius: barWindow.s(10)
                                height: leftRow.pillHeight; width: barWindow.s(32)
                                
                                Behavior on color { ColorAnimation { duration: 200 } }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰍉"
                                    font.family: "SF Pro "; font.pixelSize: barWindow.s(20)
                                    color: parent.isHovered ? mocha.blue : mocha.text
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    scale: parent.isHovered ? 1.15 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                }
                                MouseArea {
                                    id: searchMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle applauncher"])
                                }
                            }

                            Rectangle {
                                property bool isHovered: settingsMouse.containsMouse
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : "transparent"
                                radius: barWindow.s(10)
                                height: leftRow.pillHeight; width: barWindow.s(32)
                                
                                Behavior on color { ColorAnimation { duration: 200 } }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    font.family: "SF Pro "; font.pixelSize: barWindow.s(20)
                                    color: parent.isHovered ? mocha.blue : mocha.text
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    scale: parent.isHovered ? 1.15 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                }
                                MouseArea {
                                    id: settingsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle settings"])
                                }
                            }

                            Rectangle {
                                id: updateButton
                                property bool isHovered: updateMouse.containsMouse
                                color: isHovered ? Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.15) : "transparent"
                                radius: barWindow.s(10)
                                
                                width: barWindow.isUpdateVisible ? barWindow.s(32) : 0
                                height: leftRow.pillHeight
                                
                                visible: width > 0 || opacity > 0
                                opacity: barWindow.isUpdateVisible ? 1.0 : 0.0
                                clip: false 
                                
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                                
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: parent.height
                                    radius: parent.radius
                                    color: mocha.green
                                    z: -1
                                    
                                    SequentialAnimation on scale {
                                        running: barWindow.isUpdateVisible && !updateButton.isHovered
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1.0; to: 1.3; duration: 2000; easing.type: Easing.OutCubic }
                                    }
                                    SequentialAnimation on opacity {
                                        running: barWindow.isUpdateVisible && !updateButton.isHovered
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.15; to: 0.0; duration: 2000; easing.type: Easing.OutCubic }
                                    }
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰚰"
                                    font.family: "SF Pro "; font.pixelSize: barWindow.s(20)
                                    color: parent.isHovered ? mocha.text : mocha.green
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    
                                    rotation: parent.isHovered ? 360 : 0
                                    Behavior on rotation {
                                        NumberAnimation { 
                                            duration: 600
                                            easing.type: Easing.OutBack
                                        }
                                    }

                                    scale: parent.isHovered ? 1.15 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                }

                                MouseArea {
                                    id: updateMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        barWindow.updateAvailable = false;
                                        barWindow.forceUpdateShow = false;
                                        Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle updater"]);
                                    }
                                }
                            }
                        }

                        // Divider between tools and workspaces
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1
                            height: barWindow.s(18)
                            color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.15)
                            visible: workspacesModel.count > 0
                        }

                        // Workspaces Sub-Container
                        Item {
                            id: wsContainer
                            anchors.verticalCenter: parent.verticalCenter
                            width: wsLayout.implicitWidth
                            height: leftRow.pillHeight
                            visible: workspacesModel.count > 0

                            Rectangle {
                                id: activeHighlight
                                y: (parent.height - barWindow.s(30)) / 2
                                height: barWindow.s(30)
                                radius: barWindow.s(10)
                                color: mocha.mauve
                                z: 0

                                property int prevIdx: 0
                                property int curIdx: workspacesModel.activeIndex

                                onCurIdxChanged: {
                                    if (curIdx > prevIdx) {
                                        rightAnim.duration = 200; leftAnim.duration = 350;
                                    } else if (curIdx < prevIdx) {
                                        leftAnim.duration = 200; rightAnim.duration = 350;
                                    }
                                    prevIdx = curIdx;
                                }

                                property real stepSize: barWindow.s(30) + barWindow.s(6)
                                property real targetLeft: curIdx * stepSize
                                property real targetRight: targetLeft + barWindow.s(30)

                                property real actualLeft: targetLeft
                                property real actualRight: targetRight

                                Behavior on actualLeft { NumberAnimation { id: leftAnim; duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on actualRight { NumberAnimation { id: rightAnim; duration: 250; easing.type: Easing.OutExpo } }

                                x: actualLeft
                                width: actualRight - actualLeft
                                opacity: workspacesModel.count > 0 ? 1 : 0
                            }

                            Row {
                                id: wsLayout
                                anchors.centerIn: parent
                                spacing: barWindow.s(6)
                                
                                Repeater {
                                    model: workspacesModel
                                    delegate: Rectangle {
                                        id: wsPill
                                        property bool isHovered: wsPillMouse.containsMouse
                                        property string stateLabel: model.wsState
                                        property string wsName: model.wsId
                                        
                                        width: barWindow.s(30)
                                        height: barWindow.s(30)
                                        radius: barWindow.s(10)
                                        
                                        color: isHovered ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.1) : (stateLabel === "occupied" ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.15) : "transparent")

                                        scale: isHovered && stateLabel !== "active" ? 1.08 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                        
                                        property bool initAnimTrigger: false
                                        opacity: initAnimTrigger ? 1 : 0
                                        transform: Translate {
                                            y: wsPill.initAnimTrigger ? 0 : barWindow.s(15)
                                            Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                                        }

                                        Component.onCompleted: {
                                            if (!barWindow.startupCascadeFinished) {
                                                animTimer.interval = index * 60;
                                                animTimer.start();
                                            } else {
                                                initAnimTrigger = true;
                                            }
                                        }

                                        Timer {
                                            id: animTimer
                                            running: false
                                            repeat: false
                                            onTriggered: wsPill.initAnimTrigger = true
                                        }
                                        
                                        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 250 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: wsName
                                            font.family: "SF Pro Display"
                                            font.pixelSize: barWindow.s(13)
                                            font.weight: stateLabel === "active" ? Font.Black : (stateLabel === "occupied" ? Font.Bold : Font.Medium)
                                            
                                            color: index === workspacesModel.activeIndex ? mocha.crust : (isHovered ? mocha.text : (stateLabel === "occupied" ? mocha.text : mocha.overlay0))
                                            
                                            Behavior on color { ColorAnimation { duration: 250 } }
                                        }
                                        MouseArea {
                                            id: wsPillMouse
                                            hoverEnabled: true
                                            anchors.fill: parent
                                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + wsName])
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // --- 2. MIDDLE DYNAMIC ISLAND (Media, Clock/Weather, Tray) ---
                // =============================================================
                Item {
                    id: centerBox
                    property bool isHovered: centerMouse.containsMouse || centerHoverTracker.hovered
                    
                    y: 0
                    height: barWindow.barHeight
                    width: centerRow.implicitWidth + barWindow.s(28)
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }

                    HoverHandler {
                        id: centerHoverTracker
                        onHoveredChanged: {
                            if (hovered) {
                                barWindow.useCenterGraceTimer = false;
                                centerHideTimer.stop();
                            } else {
                                barWindow.kickCenterTimer();
                            }
                        }
                    }

                    MouseArea {
                        id: centerBoxDragArea
                        anchors.fill: parent
                        anchors.margins: -barWindow.s(6)
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        z: -1
                        onEntered: {
                            barWindow.useCenterGraceTimer = false;
                            centerHideTimer.stop();
                        }
                        onExited: barWindow.kickCenterTimer()
                    }

                    IslandBackground {
                        hasTopLeftEar: true
                        hasTopRightEar: true
                        hasBottomLeftEar: false
                        hasBottomRightEar: false
                        earRadius: barWindow.s(14)
                        bottomRadius: barWindow.s(14)
                        fillColor: barWindow.isWindowFullscreen ? (centerBox.isHovered ? Qt.rgba(0.08, 0.08, 0.08, 1.0) : "#000000") : (centerBox.isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.85) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75))
                        strokeColor: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, centerBox.isHovered ? 0.18 : 0.12)
                        Behavior on fillColor { ColorAnimation { duration: 200 } }
                        Behavior on strokeColor { ColorAnimation { duration: 200 } }
                    }
                    
                    property real leftBound: leftBox.x + leftBox.width
                    property real rightBound: rightBox.x
                    x: Math.max(leftBound + barWindow.s(16), (leftBound + rightBound - width) / 2)
                    Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                    
                    property bool showLayout: false
                    opacity: barWindow.isCenterHidden ? 0.0 : (showLayout ? 1 : 0)
                    transform: Translate {
                        y: barWindow.isCenterHidden ? -(barWindow.barHeight + barWindow.s(20)) : (centerBox.showLayout ? 0 : barWindow.s(-30))
                        Behavior on y { NumberAnimation { duration: 300; easing.type: barWindow.isCenterHidden ? Easing.InCubic : Easing.OutCubic } }
                    }

                    Timer {
                        running: barWindow.isStartupReady
                        interval: 150
                        onTriggered: centerBox.showLayout = true
                    }

                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                    Row {
                        id: centerRow
                        anchors.centerIn: parent
                        spacing: barWindow.s(12)

                        // 1. Dynamic Media Section
                        Row {
                            id: mediaSection
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: barWindow.s(10)
                            visible: barWindow.isMediaActive
                            opacity: barWindow.isMediaActive ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 300 } }

                            MouseArea {
                                id: mediaInfoMouse
                                width: infoLayout.width
                                height: barWindow.barHeight
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle music"])
                                
                                Row {
                                    id: infoLayout
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: barWindow.s(10)
                                    
                                    scale: mediaInfoMouse.containsMouse ? 1.02 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                    Item {
                                        width: barWindow.s(28); height: barWindow.s(28)

                                        // Base placeholder background
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: barWindow.s(8)
                                            color: mocha.surface1
                                        }

                                        // Rounded Mask for art & tint
                                        Rectangle {
                                            id: mediaArtMask
                                            anchors.fill: parent
                                            radius: barWindow.s(8)
                                            visible: false
                                            layer.enabled: true
                                        }

                                        // Content Layer
                                        Item {
                                            id: mediaArtContent
                                            anchors.fill: parent
                                            visible: false
                                            layer.enabled: true

                                            Image { 
                                                anchors.fill: parent
                                                source: barWindow.displayArtUrl || ""
                                                fillMode: Image.PreserveAspectCrop 
                                            }
                                            
                                            Rectangle {
                                                anchors.fill: parent
                                                color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.2)
                                            }
                                        }

                                        // Masked Effect
                                        MultiEffect {
                                            anchors.fill: parent
                                            source: mediaArtContent
                                            maskEnabled: true
                                            maskSource: mediaArtMask
                                            opacity: (barWindow.displayArtUrl && barWindow.displayArtUrl !== "") ? 1.0 : 0.0
                                        }

                                        // Border overlay with matching corner radius
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: barWindow.s(8)
                                            color: "transparent"
                                            border.width: barWindow.musicData.status === "Playing" ? 1 : 0
                                            border.color: mocha.mauve
                                        }
                                    }
                                    Column {
                                        spacing: -2
                                        anchors.verticalCenter: parent.verticalCenter
                                        property real maxColWidth: barWindow.width < 1920 ? barWindow.s(110) : barWindow.s(160)
                                        width: maxColWidth 
                                        
                                        Text { 
                                            text: barWindow.displayTitle; 
                                            font.family: "SF Pro Text"; 
                                            font.weight: Font.Black; 
                                            font.pixelSize: barWindow.s(12); 
                                            color: mocha.text;
                                            width: parent.width
                                            elide: Text.ElideRight; 
                                        }
                                        Text { 
                                            text: barWindow.displayTime; 
                                            font.family: "SF Pro Text"; 
                                            font.weight: Font.Black; 
                                            font.pixelSize: barWindow.s(9); 
                                            color: mocha.subtext0;
                                            width: parent.width
                                            elide: Text.ElideRight; 
                                        }
                                    }
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: barWindow.s(6)
                                Item { 
                                    width: barWindow.s(20); height: barWindow.s(20); 
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { 
                                        anchors.centerIn: parent; text: "󰒮"; font.family: "SF Pro "; font.pixelSize: barWindow.s(22); 
                                        color: prevMouse.containsMouse ? mocha.text : mocha.overlay2; 
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        scale: prevMouse.containsMouse ? 1.1 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }
                                    MouseArea { id: prevMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "previous"]); musicForceRefresh.running = true; } } 
                                }
                                Item { 
                                    width: barWindow.s(24); height: barWindow.s(24); 
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { 
                                        anchors.centerIn: parent; text: barWindow.musicData.status === "Playing" ? "󰏤" : "󰐊"; font.family: "SF Pro "; font.pixelSize: barWindow.s(26); 
                                        color: playMouse.containsMouse ? mocha.green : mocha.text; 
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        scale: playMouse.containsMouse ? 1.15 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }
                                    MouseArea { id: playMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "play-pause"]); musicForceRefresh.running = true; } } 
                                }
                                Item { 
                                    width: barWindow.s(20); height: barWindow.s(20); 
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { 
                                        anchors.centerIn: parent; text: "󰒭"; font.family: "SF Pro "; font.pixelSize: barWindow.s(22); 
                                        color: nextMouse.containsMouse ? mocha.text : mocha.overlay2; 
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        scale: nextMouse.containsMouse ? 1.1 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }
                                    MouseArea { id: nextMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "next"]); musicForceRefresh.running = true; } } 
                                }
                            }
                        }

                        // Divider 1 (between media and clock)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1
                            height: barWindow.s(18)
                            color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.15)
                            visible: barWindow.isMediaActive
                        }

                        // 2. Clock & Weather Section
                        Item {
                            id: clockWeatherSection
                            width: centerLayout.implicitWidth
                            height: barWindow.barHeight

                            MouseArea {
                                id: centerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle calendar"])
                            }

                            RowLayout {
                                id: centerLayout
                                anchors.centerIn: parent
                                spacing: barWindow.s(18)

                                ColumnLayout {
                                    spacing: -2
                                    Text { 
                                        text: barWindow.timeStr; 
                                        Layout.alignment: Qt.AlignLeft; 
                                        font.family: "SF Pro Display"; 
                                        font.pixelSize: barWindow.s(15); 
                                        font.weight: Font.Black; 
                                        color: mocha.blue 
                                    }
                                    Text { 
                                        text: barWindow.dateStr; 
                                        Layout.alignment: Qt.AlignLeft; 
                                        font.family: "SF Pro Text"; 
                                        font.pixelSize: barWindow.s(10); 
                                        font.weight: Font.Bold; 
                                        color: mocha.subtext0 
                                    }
                                }

                                RowLayout {
                                    spacing: barWindow.s(6)
                                    Text { 
                                        text: barWindow.weatherIcon; 
                                        Layout.alignment: Qt.AlignVCenter;
                                        font.family: "SF Pro "; 
                                        font.pixelSize: barWindow.s(20); 
                                        color: Qt.tint(barWindow.weatherHex, Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.4)) 
                                    }
                                    Text { 
                                        text: barWindow.weatherTemp; 
                                        Layout.alignment: Qt.AlignVCenter;
                                        font.family: "SF Pro Text"; 
                                        font.pixelSize: barWindow.s(14); 
                                        font.weight: Font.Black; 
                                        color: mocha.peach 
                                    }
                                }
                            }
                        }

                        // Divider 2 (between clock and tray)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1
                            height: barWindow.s(18)
                            color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.15)
                            visible: trayRepeater.count > 0
                        }

                        // 3. System Tray Section
                        Row {
                            id: traySection
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: barWindow.s(8)
                            visible: trayRepeater.count > 0

                            Repeater {
                                id: trayRepeater
                                model: SystemTray.items
                                delegate: Image {
                                    id: trayIcon
                                    source: modelData.icon || ""
                                    fillMode: Image.PreserveAspectFit
                                    
                                    sourceSize: Qt.size(barWindow.s(16), barWindow.s(16))
                                    width: barWindow.s(16)
                                    height: barWindow.s(16)
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    property bool isHovered: trayMouse.containsMouse
                                    property bool initAnimTrigger: false
                                    opacity: initAnimTrigger ? (isHovered ? 1.0 : 0.8) : 0.0
                                    scale: initAnimTrigger ? (isHovered ? 1.15 : 1.0) : 0.0

                                    Component.onCompleted: {
                                        if (!barWindow.startupCascadeFinished) {
                                            trayAnimTimer.interval = index * 50;
                                            trayAnimTimer.start();
                                        } else {
                                            initAnimTrigger = true;
                                        }
                                    }
                                    Timer {
                                        id: trayAnimTimer
                                        running: false
                                        repeat: false
                                        onTriggered: trayIcon.initAnimTrigger = true
                                    }

                                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                    QsMenuAnchor {
                                        id: menuAnchor
                                        anchor.window: barWindow
                                        anchor.item: trayIcon
                                        menu: modelData.menu
                                    }

                                    MouseArea {
                                        id: trayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.LeftButton) {
                                                if (modelData.isMenuOnly || modelData.onlyMenu) {
                                                    menuAnchor.open();
                                                } else if (typeof modelData.activate === "function") {
                                                    modelData.activate(); 
                                                }
                                            } else if (mouse.button === Qt.MiddleButton) {
                                                if (typeof modelData.secondaryActivate === "function") {
                                                    modelData.secondaryActivate();
                                                }
                                            } else if (mouse.button === Qt.RightButton) {
                                                if (modelData.menu) { 
                                                    menuAnchor.open();
                                                } else if (typeof modelData.contextMenu === "function") {
                                                    modelData.contextMenu(mouse.x, mouse.y);
                                                } else {
                                                    modelData.activate(); 
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // --- 3. RIGHT DYNAMIC ISLAND (Status Indicators & Recording) ---
                // =============================================================
                Item {
                    id: rightBox
                    anchors.right: parent.right
                    y: 0
                    height: barWindow.barHeight
                    width: sysLayout.implicitWidth + barWindow.s(22)
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }

                    HoverHandler {
                        id: rightHoverTracker
                        onHoveredChanged: {
                            if (hovered) {
                                barWindow.useRightGraceTimer = false;
                                rightHideTimer.stop();
                            } else {
                                barWindow.kickRightTimer();
                            }
                        }
                    }

                    MouseArea {
                        id: rightBoxDragArea
                        anchors.fill: parent
                        anchors.margins: -barWindow.s(6)
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        z: -1
                        onEntered: {
                            barWindow.useRightGraceTimer = false;
                            rightHideTimer.stop();
                        }
                        onExited: barWindow.kickRightTimer()
                    }

                    IslandBackground {
                        hasTopLeftEar: true
                        hasTopRightEar: false
                        hasBottomRightEar: true
                        hasBottomLeftRadius: true
                        hasBottomRightRadius: false
                        earRadius: barWindow.s(14)
                        bottomRadius: barWindow.s(14)
                        fillColor: barWindow.isWindowFullscreen ? "#000000" : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        strokeColor: barWindow.isWindowFullscreen ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.15) : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
                        Behavior on fillColor { ColorAnimation { duration: 200 } }
                        Behavior on strokeColor { ColorAnimation { duration: 200 } }
                    }
                    
                    property bool showLayout: false
                    opacity: barWindow.isRightHidden ? 0.0 : (showLayout ? 1 : 0)
                    transform: Translate {
                        x: barWindow.isRightHidden ? (rightBox.width + barWindow.s(20)) : (rightBox.showLayout ? 0 : barWindow.s(30))
                        y: barWindow.isRightHidden ? -(barWindow.barHeight + barWindow.s(20)) : 0
                        Behavior on x { NumberAnimation { duration: 300; easing.type: barWindow.isRightHidden ? Easing.InCubic : Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 300; easing.type: barWindow.isRightHidden ? Easing.InCubic : Easing.OutCubic } }
                    }
                    
                    Timer {
                        running: barWindow.isStartupReady && barWindow.isDataReady
                        interval: 250
                        onTriggered: rightBox.showLayout = true
                    }

                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                    Row {
                        id: sysLayout
                        anchors.centerIn: parent
                        spacing: barWindow.s(8) 

                        property int pillHeight: barWindow.s(32)

                        Rectangle {
                            id: kbPill
                            property bool isHovered: kbMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                            radius: barWindow.s(10); height: sysLayout.pillHeight;
                            clip: true
                            
                            property real targetWidth: kbLayoutRow.implicitWidth + barWindow.s(24)
                            width: targetWidth
                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                            
                            scale: isHovered ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            Behavior on color { ColorAnimation { duration: 200 } }

                            property bool initAnimTrigger: false
                            Timer { running: rightBox.showLayout && !kbPill.initAnimTrigger; interval: 0; onTriggered: kbPill.initAnimTrigger = true }
                            opacity: initAnimTrigger ? 1 : 0
                            transform: Translate { y: kbPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                            Row { 
                                id: kbLayoutRow
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: barWindow.s(12)
                                spacing: barWindow.s(8)
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "󰌌"; font.family: "SF Pro "; font.pixelSize: barWindow.s(16); color: parent.parent.isHovered ? mocha.text : mocha.overlay2 }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: barWindow.kbLayout; font.family: "SF Pro Text"; font.pixelSize: barWindow.s(13); font.weight: Font.Black; color: mocha.text }
                            }
                            MouseArea { id: kbMouse; anchors.fill: parent; hoverEnabled: true; onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]) }
                        }

                        Rectangle {
                            id: wifiPill
                            property bool isHovered: wifiMouse.containsMouse
                            radius: barWindow.s(10); height: sysLayout.pillHeight; 
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                            clip: true
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: barWindow.s(10)
                                opacity: barWindow.showEthernet ? (barWindow.ethStatus === "Connected" ? 1.0 : 0.0) : (barWindow.isWifiOn ? 1.0 : 0.0)
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: mocha.blue }
                                    GradientStop { position: 1.0; color: Qt.lighter(mocha.blue, 1.3) }
                                }
                            }

                            property real targetWidth: wifiLayoutRow.implicitWidth + barWindow.s(24)
                            width: targetWidth
                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                            
                            scale: isHovered ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            Behavior on color { ColorAnimation { duration: 200 } }

                            property bool initAnimTrigger: false
                            Timer { running: rightBox.showLayout && !wifiPill.initAnimTrigger; interval: 50; onTriggered: wifiPill.initAnimTrigger = true }
                            opacity: initAnimTrigger ? 1 : 0
                            transform: Translate { y: wifiPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                            Row { 
                                id: wifiLayoutRow
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: barWindow.s(12)
                                spacing: barWindow.s(8)
                                Text { 
                                    anchors.verticalCenter: parent.verticalCenter; 
                                    text: barWindow.showEthernet ? "󰈀" : barWindow.wifiIcon;
                                    font.family: "SF Pro "; font.pixelSize: barWindow.s(16);
                                    color: barWindow.showEthernet ? (barWindow.ethStatus === "Connected" ? mocha.crust : mocha.subtext0) : (barWindow.isWifiOn ? mocha.crust : mocha.subtext0)
                                }
                                Text { 
                                    id: wifiText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: barWindow.showEthernet ? barWindow.ethStatus : ((barWindow.isWifiOn ? (barWindow.wifiSsid !== "" ? barWindow.wifiSsid : "On") : "Off"))
                                    visible: text !== ""
                                    font.family: "SF Pro Text"; font.pixelSize: barWindow.s(13); font.weight: Font.Black;
                                    color: barWindow.showEthernet ? (barWindow.ethStatus === "Connected" ? mocha.crust : mocha.text) : (barWindow.isWifiOn ? mocha.crust : mocha.text);
                                    width: Math.min(implicitWidth, barWindow.s(100)); elide: Text.ElideRight 
                                }
                            }
                            MouseArea { id: wifiMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network wifi"]) }
                        }

                        Rectangle {
                            id: btPill
                            property bool isHovered: btMouse.containsMouse
                            radius: barWindow.s(10); height: sysLayout.pillHeight
                            clip: true
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: barWindow.s(10)
                                opacity: barWindow.isBtOn ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: mocha.mauve }
                                    GradientStop { position: 1.0; color: Qt.lighter(mocha.mauve, 1.3) }
                                }
                            }

                            property real targetWidth: barWindow.isDesktop ? 0 : btLayoutRow.implicitWidth + barWindow.s(24)
                            width: targetWidth
                            visible: targetWidth > 0
                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                            scale: isHovered ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            Behavior on color { ColorAnimation { duration: 200 } }

                            property bool initAnimTrigger: false
                            Timer { running: rightBox.showLayout && !btPill.initAnimTrigger; interval: 100; onTriggered: btPill.initAnimTrigger = true }
                            opacity: initAnimTrigger ? 1 : 0
                            transform: Translate { y: btPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                            Row { 
                                id: btLayoutRow
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: barWindow.s(12)
                                spacing: barWindow.s(8)
                                Text { anchors.verticalCenter: parent.verticalCenter; text: barWindow.btIcon; font.family: "SF Pro "; font.pixelSize: barWindow.s(16); color: barWindow.isBtOn ? mocha.crust : mocha.subtext0 }
                                Text { 
                                    id: btText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: barWindow.btDevice
                                    visible: text !== ""; 
                                    font.family: "SF Pro Text"; font.pixelSize: barWindow.s(13); font.weight: Font.Black; 
                                    color: barWindow.isBtOn ? mocha.crust : mocha.text; 
                                    width: Math.min(implicitWidth, barWindow.s(100)); elide: Text.ElideRight 
                                }
                            }
                            MouseArea { id: btMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network bt"]) }
                        }

                        Rectangle {
                            id: volPill
                            property bool isHovered: volMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                            radius: barWindow.s(10); height: sysLayout.pillHeight;
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                radius: barWindow.s(10)
                                opacity: barWindow.isSoundActive ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: mocha.peach }
                                    GradientStop { position: 1.0; color: Qt.lighter(mocha.peach, 1.3) }
                                }
                            }
                            
                            property real targetWidth: volLayoutRow.implicitWidth + barWindow.s(24)
                            width: targetWidth
                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                            
                            scale: isHovered ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            Behavior on color { ColorAnimation { duration: 200 } }

                            property bool initAnimTrigger: false
                            Timer { running: rightBox.showLayout && !volPill.initAnimTrigger; interval: 150; onTriggered: volPill.initAnimTrigger = true }
                            opacity: initAnimTrigger ? 1 : 0
                            transform: Translate { y: volPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                            Row { 
                                id: volLayoutRow
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: barWindow.s(12)
                                spacing: barWindow.s(8)
                                Text { 
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: barWindow.volIcon; font.family: "SF Pro "; font.pixelSize: barWindow.s(16); 
                                    color: barWindow.isSoundActive ? mocha.crust : mocha.subtext0 
                                }
                                Text { 
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: barWindow.volPercent; 
                                    font.family: "SF Pro Text"; font.pixelSize: barWindow.s(13); font.weight: Font.Black; 
                                    color: barWindow.isSoundActive ? mocha.crust : mocha.text; 
                                }
                            }
                            MouseArea { id: volMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle volume"]) }
                        }

                        Rectangle {
                            id: monPill
                            property bool isHovered: monMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                            radius: barWindow.s(10); height: sysLayout.pillHeight;
                            clip: true
                            
                            property real targetWidth: monLayoutRow.implicitWidth + barWindow.s(24)
                            width: targetWidth
                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                            
                            scale: isHovered ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            Behavior on color { ColorAnimation { duration: 200 } }

                            property bool initAnimTrigger: false
                            Timer { running: rightBox.showLayout && !monPill.initAnimTrigger; interval: 175; onTriggered: monPill.initAnimTrigger = true }
                            opacity: initAnimTrigger ? 1 : 0
                            transform: Translate { y: monPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                            Row { 
                                id: monLayoutRow
                                anchors.centerIn: parent
                                Text { 
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰍹"
                                    font.family: "SF Pro "; font.pixelSize: barWindow.s(16); 
                                    color: monMouse.containsMouse ? mocha.text : mocha.overlay2
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                            MouseArea { id: monMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle monitors"]) }
                        }

                        // Notification Pill
                        Item {
                            id: notifPillItem
                            property int unreadNotifCount: 0
                            width: notifPillRect.width
                            height: sysLayout.pillHeight

                            Process {
                                id: notifCountPoller
                                command: ["bash", "-c", "cat " + paths.runDir + "/notif_count 2>/dev/null || echo '0'"]
                                stdout: StdioCollector {
                                    onStreamFinished: notifPillItem.unreadNotifCount = parseInt(this.text.trim()) || 0
                                }
                            }
                            Timer {
                                interval: 500; running: true; repeat: true; triggeredOnStart: true
                                onTriggered: notifCountPoller.running = true
                            }

                            Rectangle {
                                id: notifPillRect
                                property bool isHovered: notifMouse.containsMouse
                                property bool hasUnread: notifPillItem.unreadNotifCount > 0

                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : (hasUnread ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4))
                                radius: barWindow.s(10); height: sysLayout.pillHeight;
                                clip: true

                                property real targetWidth: notifLayoutRow.implicitWidth + barWindow.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightBox.showLayout && !notifPillRect.initAnimTrigger; interval: 190; onTriggered: notifPillRect.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: notifPillRect.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: notifLayoutRow
                                    anchors.centerIn: parent
                                    spacing: barWindow.s(6)
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰂚"
                                        font.family: "SF Pro "; font.pixelSize: barWindow.s(16);
                                        color: notifMouse.containsMouse ? mocha.text : (notifPillRect.hasUnread ? mocha.mauve : mocha.overlay2)
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: notifPillItem.unreadNotifCount > 0
                                        text: notifPillItem.unreadNotifCount
                                        font.family: "SF Pro Text"; font.pixelSize: barWindow.s(12); font.weight: Font.Bold
                                        color: notifMouse.containsMouse ? mocha.text : mocha.mauve
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                                MouseArea { id: notifMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle notifications"]) }
                            }
                        }

                        Rectangle {
                            id: batPill
                            property bool isHovered: batMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4); 
                            radius: barWindow.s(10); height: sysLayout.pillHeight;
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                radius: barWindow.s(10)
                                opacity: 1.0 
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: barWindow.isDesktop ? mocha.red : barWindow.batDynamicColor; Behavior on color { ColorAnimation { duration: 300 } } }
                                    GradientStop { position: 1.0; color: barWindow.isDesktop ? Qt.lighter(mocha.red, 1.3) : Qt.lighter(barWindow.batDynamicColor, 1.3); Behavior on color { ColorAnimation { duration: 300 } } }
                                }
                            }
                            
                            property real targetWidth: barWindow.isDesktop ? barWindow.s(32) : batLayoutRow.implicitWidth + barWindow.s(24)
                            width: targetWidth
                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                            
                            scale: isHovered ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            Behavior on color { ColorAnimation { duration: 200 } }

                            property bool initAnimTrigger: false
                            Timer { running: rightBox.showLayout && !batPill.initAnimTrigger; interval: 195; onTriggered: batPill.initAnimTrigger = true }
                            opacity: initAnimTrigger ? 1 : 0
                            transform: Translate { y: batPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                            Row { 
                                id: batLayoutRow
                                anchors.centerIn: parent
                                spacing: barWindow.s(8)
                                Text { 
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: barWindow.isDesktop ? "" : barWindow.batIcon; 
                                    font.family: "SF Pro "; font.pixelSize: barWindow.isDesktop ? barWindow.s(18) : barWindow.s(16); 
                                    color: mocha.crust 
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                                Text { 
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !barWindow.isDesktop
                                    text: barWindow.batPercent; font.family: "SF Pro Text"; font.pixelSize: barWindow.s(13); font.weight: Font.Black; 
                                    color: mocha.crust 
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                            }
                            MouseArea { id: batMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle battery"]) }
                        }

                        // Hardware / Power Settings Pill
                        Rectangle {
                            id: hwPill
                            property bool isHovered: hwMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                            radius: barWindow.s(10); height: sysLayout.pillHeight;
                            clip: true

                            property real targetWidth: barWindow.hasHwFeatures ? hwLayoutRow.implicitWidth + barWindow.s(24) : 0
                            width: targetWidth
                            visible: targetWidth > 0
                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                            scale: isHovered ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            Behavior on color { ColorAnimation { duration: 200 } }

                            property bool initAnimTrigger: false
                            Timer { running: rightBox.showLayout && !hwPill.initAnimTrigger; interval: 205; onTriggered: hwPill.initAnimTrigger = true }
                            opacity: initAnimTrigger ? 1 : 0
                            transform: Translate { y: hwPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                            Row {
                                id: hwLayoutRow
                                anchors.centerIn: parent
                                spacing: barWindow.s(6)
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "" 
                                    font.family: "SF Pro "
                                    font.pixelSize: barWindow.s(16)
                                    color: hwMouse.containsMouse ? mocha.text : (barWindow.isHwTurboOn ? mocha.peach : mocha.overlay2)
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                            MouseArea {
                                id: hwMouse
                                hoverEnabled: true
                                anchors.fill: parent
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle hardware"])
                            }
                        }

                        // Screen Recording Indicator inside the Right Pill
                        Rectangle {
                            id: recPill
                            property bool isHovered: recMouse.containsMouse
                            
                            property real targetWidth: barWindow.isRecording ? barWindow.s(32) : 0
                            width: targetWidth
                            height: sysLayout.pillHeight 
                            radius: barWindow.s(10)
                            color: isHovered ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.3) : Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.15)
                            border.width: 1
                            border.color: Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.4)

                            visible: targetWidth > 0 || opacity > 0
                            opacity: barWindow.isRecording ? 1.0 : 0.0

                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            scale: isHovered ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                            Text {
                                id: recIcon
                                anchors.centerIn: parent
                                text: "" 
                                font.family: "SF Pro "
                                font.pixelSize: barWindow.s(18)
                                color: mocha.red
                                
                                SequentialAnimation on opacity {
                                    running: barWindow.isRecording && !recPill.isHovered
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                                }
                                SequentialAnimation on scale {
                                    running: barWindow.isRecording && !recPill.isHovered
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 1.15; duration: 600; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                                }
                            }
                            
                            MouseArea {
                                id: recMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    barWindow.isRecording = false; 
                                    Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/screenshot.sh"]); 
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
