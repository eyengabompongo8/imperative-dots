import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: cornerOverlay
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "qs-screen-corners"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Zero input interception: clicks pass through completely
            mask: Region {}

            // Configuration properties with live updates
            property bool cornersEnabled: true
            property real cornerRadius: 14
            property color cornerColor: "#000000"

            Scaler {
                id: scaler
                currentWidth: cornerOverlay.screen.width
                currentHeight: cornerOverlay.screen.height
            }

            property real effectiveRadius: scaler.s(cornerRadius)

            // Dynamic Settings Watcher
            Process {
                id: settingsReader
                command: ["bash", "-c", "cat ~/.config/hypr/settings.json 2>/dev/null || echo '{}'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            if (this.text && this.text.trim().length > 0 && this.text.trim() !== "{}") {
                                let parsed = JSON.parse(this.text);
                                if (parsed.screenCornersEnabled !== undefined) {
                                    cornerOverlay.cornersEnabled = parsed.screenCornersEnabled;
                                }
                                if (parsed.screenCornerRadius !== undefined) {
                                    cornerOverlay.cornerRadius = parsed.screenCornerRadius;
                                }
                                if (parsed.screenCornerColor !== undefined) {
                                    cornerOverlay.cornerColor = parsed.screenCornerColor;
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

            Item {
                anchors.fill: parent
                visible: cornerOverlay.cornersEnabled && cornerOverlay.effectiveRadius > 0

                component CornerPiece: Shape {
                    id: piece
                    property real radiusVal: cornerOverlay.effectiveRadius
                    property color fillCol: cornerOverlay.cornerColor

                    width: radiusVal
                    height: radiusVal
                    layer.enabled: true
                    layer.samples: 4

                    ShapePath {
                        fillColor: piece.fillCol
                        strokeColor: "transparent"
                        startX: 0
                        startY: 0
                        PathLine { x: piece.radiusVal; y: 0 }
                        PathArc {
                            x: 0
                            y: piece.radiusVal
                            radiusX: piece.radiusVal
                            radiusY: piece.radiusVal
                            direction: PathArc.Counterclockwise
                        }
                        PathLine { x: 0; y: 0 }
                    }
                }

                // Top-Left
                CornerPiece {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    rotation: 0
                }

                // Top-Right
                CornerPiece {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    rotation: 90
                }

                // Bottom-Right
                CornerPiece {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    rotation: 180
                }

                // Bottom-Left
                CornerPiece {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    rotation: 270
                }
            }
        }
    }
}
