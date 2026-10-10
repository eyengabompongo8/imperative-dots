import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real pillWidth: parent ? parent.width : 0
    property real pillHeight: parent ? parent.height : 0
    property real earRadius: 14
    property real bottomRadius: 14

    property bool hasTopLeftEar: true
    property bool hasTopRightEar: true
    property bool hasBottomLeftEar: false
    property bool hasBottomRightEar: false

    property bool hasBottomLeftRadius: !hasBottomLeftEar
    property bool hasBottomRightRadius: !hasBottomRightEar

    // Aliases for convenience
    property alias hasLeftEar: root.hasTopLeftEar
    property alias hasRightEar: root.hasTopRightEar

    readonly property real leftOffset: hasTopLeftEar ? root.earRadius : 0
    readonly property real rightOffset: (hasTopRightEar && !hasBottomRightEar) ? root.earRadius : 0
    readonly property real bottomOffset: (hasBottomLeftEar || hasBottomRightEar) ? root.earRadius : 0

    property color fillColor: Qt.rgba(0.12, 0.12, 0.18, 0.75)
    property color strokeColor: Qt.rgba(1, 1, 1, 0.12)
    property real strokeWidth: 1.2

    property real overshootExtension: 0
    readonly property real topExtension: root.overshootExtension
    readonly property real leftBezelExtension: root.hasBottomLeftEar ? root.overshootExtension : 0
    readonly property real rightBezelExtension: root.hasBottomRightEar ? root.overshootExtension : 0

    anchors.top: parent ? parent.top : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    anchors.topMargin: -root.topExtension
    anchors.leftMargin: -(root.leftOffset + root.leftBezelExtension)
    anchors.rightMargin: -(root.rightOffset + root.rightBezelExtension)
    anchors.bottomMargin: -root.bottomOffset

    z: -1

    // Fill Shape (closed polygon)
    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        smooth: true

        // CASE 1: Left Corner Pill (hasBottomLeftEar: true)
        ShapePath {
            fillColor: root.hasBottomLeftEar ? root.fillColor : "transparent"
            strokeColor: "transparent"
            strokeWidth: 0

            // 1. Top-Left extended corner beyond top-left screen bezel
            startX: 0
            startY: 0

            // 2. Straight down left monitor bezel to bottom-left ear
            PathLine {
                x: 0
                y: root.topExtension + root.pillHeight + root.earRadius
            }

            // 3. Straight across bezel extension to screen bezel
            PathLine {
                x: root.leftBezelExtension
                y: root.topExtension + root.pillHeight + root.earRadius
            }

            // 4. Bottom-Left concave ear curving into bottom edge at (Re + leftBezelExtension, H + topExtension)
            PathArc {
                x: root.leftBezelExtension + root.earRadius
                y: root.topExtension + root.pillHeight
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 4. Bottom horizontal edge
            PathLine {
                x: Math.max(root.leftBezelExtension + root.earRadius, root.leftBezelExtension + root.pillWidth - root.bottomRadius)
                y: root.topExtension + root.pillHeight
            }

            // 5. Bottom-Right convex corner
            PathArc {
                x: root.leftBezelExtension + root.pillWidth
                y: root.topExtension + root.pillHeight - root.bottomRadius
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 6. Right vertical wall
            PathLine {
                x: root.leftBezelExtension + root.pillWidth
                y: root.topExtension + root.earRadius
            }

            // 7. Top-Right concave ear
            PathArc {
                x: root.leftBezelExtension + root.pillWidth + root.earRadius
                y: root.topExtension
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 8. Straight up into the top bezel extension
            PathLine {
                x: root.leftBezelExtension + root.pillWidth + root.earRadius
                y: 0
            }

            // 9. Close along top screen bezel extension
            PathLine {
                x: 0
                y: 0
            }
        }

        // CASE 2: Right Corner Pill (hasBottomRightEar: true)
        ShapePath {
            fillColor: (root.hasBottomRightEar && !root.hasBottomLeftEar) ? root.fillColor : "transparent"
            strokeColor: "transparent"
            strokeWidth: 0

            // 1. Top-Left extended start
            startX: 0
            startY: 0

            // 2. Straight down to top-left ear
            PathLine {
                x: 0
                y: root.topExtension
            }

            // 3. Top-Left concave ear to (Re, Re + topExtension)
            PathArc {
                x: root.earRadius
                y: root.topExtension + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 4. Left vertical wall
            PathLine {
                x: root.earRadius
                y: root.topExtension + root.pillHeight - root.bottomRadius
            }

            // 5. Bottom-Left convex corner
            PathArc {
                x: root.earRadius + root.bottomRadius
                y: root.topExtension + root.pillHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 6. Bottom horizontal edge
            PathLine {
                x: Math.max(root.earRadius + root.bottomRadius, root.pillWidth)
                y: root.topExtension + root.pillHeight
            }

            // 7. Bottom-Right concave ear curving to right screen bezel
            PathArc {
                x: root.pillWidth + root.earRadius
                y: root.topExtension + root.pillHeight + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 8. Straight into right bezel extension
            PathLine {
                x: root.pillWidth + root.earRadius + root.rightBezelExtension
                y: root.topExtension + root.pillHeight + root.earRadius
            }

            // 9. Right vertical bezel edge up to top-right corner
            PathLine {
                x: root.pillWidth + root.earRadius + root.rightBezelExtension
                y: 0
            }

            // 10. Close along top bezel extension
            PathLine {
                x: 0
                y: 0
            }
        }

        // CASE 3: Interior Island (!hasBottomLeftEar && !hasBottomRightEar)
        ShapePath {
            fillColor: (!root.hasBottomLeftEar && !root.hasBottomRightEar) ? root.fillColor : "transparent"
            strokeColor: "transparent"
            strokeWidth: 0

            // 1. Top-Left start beyond top bezel
            startX: 0
            startY: 0

            // 2. Straight down to top-left ear start
            PathLine {
                x: 0
                y: root.topExtension
            }

            // 3. Top-Left concave ear to (Re, Re + topExtension)
            PathArc {
                x: root.earRadius
                y: root.topExtension + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 4. Left vertical wall
            PathLine {
                x: root.earRadius
                y: root.topExtension + root.pillHeight - root.bottomRadius
            }

            // 5. Bottom-Left convex corner
            PathArc {
                x: root.earRadius + root.bottomRadius
                y: root.topExtension + root.pillHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 6. Bottom horizontal edge
            PathLine {
                x: Math.max(root.earRadius + root.bottomRadius, root.pillWidth + root.earRadius - root.bottomRadius)
                y: root.topExtension + root.pillHeight
            }

            // 7. Bottom-Right convex corner
            PathArc {
                x: root.pillWidth + root.earRadius
                y: root.topExtension + root.pillHeight - root.bottomRadius
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 8. Right vertical wall
            PathLine {
                x: root.pillWidth + root.earRadius
                y: root.topExtension + root.earRadius
            }

            // 9. Top-Right concave ear
            PathArc {
                x: root.pillWidth + 2 * root.earRadius
                y: root.topExtension
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 10. Straight up into top bezel extension
            PathLine {
                x: root.pillWidth + 2 * root.earRadius
                y: 0
            }

            // 11. Close along top bezel extension
            PathLine {
                x: 0
                y: 0
            }
        }
    }

    // Border Stroke Shape (open path: outlines floating perimeter only)
    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        smooth: true
        visible: root.strokeWidth > 0 && root.strokeColor !== "transparent"

        // CASE 1: Left Corner Pill (hasBottomLeftEar)
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.hasBottomLeftEar ? root.strokeColor : "transparent"
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            // Start in left bezel extension
            startX: 0
            startY: root.topExtension + root.pillHeight + root.earRadius

            // Straight across bezel extension to screen bezel
            PathLine {
                x: root.leftBezelExtension
                y: root.topExtension + root.pillHeight + root.earRadius
            }

            // Bottom-left concave ear into bottom edge
            PathArc {
                x: root.leftBezelExtension + root.earRadius
                y: root.topExtension + root.pillHeight
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // Bottom edge
            PathLine {
                x: Math.max(root.leftBezelExtension + root.earRadius, root.leftBezelExtension + root.pillWidth - root.bottomRadius)
                y: root.topExtension + root.pillHeight
            }

            // Bottom-right convex corner
            PathArc {
                x: root.leftBezelExtension + root.pillWidth
                y: root.topExtension + root.pillHeight - root.bottomRadius
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // Right wall
            PathLine {
                x: root.leftBezelExtension + root.pillWidth
                y: root.topExtension + root.earRadius
            }

            // Top-right concave ear
            PathArc {
                x: root.leftBezelExtension + root.pillWidth + root.earRadius
                y: root.topExtension
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // Continue straight up into top bezel extension
            PathLine {
                x: root.leftBezelExtension + root.pillWidth + root.earRadius
                y: 0
            }
        }

        // CASE 2: Right Corner Pill (hasBottomRightEar)
        ShapePath {
            fillColor: "transparent"
            strokeColor: (root.hasBottomRightEar && !root.hasBottomLeftEar) ? root.strokeColor : "transparent"
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            // Start in top-left extension
            startX: 0
            startY: 0

            // Straight down to top-left ear
            PathLine {
                x: 0
                y: root.topExtension
            }

            // Top-left concave ear
            PathArc {
                x: root.earRadius
                y: root.topExtension + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // Left wall
            PathLine {
                x: root.earRadius
                y: root.topExtension + root.pillHeight - root.bottomRadius
            }

            // Bottom-left convex corner
            PathArc {
                x: root.earRadius + root.bottomRadius
                y: root.topExtension + root.pillHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // Bottom horizontal edge
            PathLine {
                x: Math.max(root.earRadius + root.bottomRadius, root.pillWidth)
                y: root.topExtension + root.pillHeight
            }

            // Bottom-right concave ear to right screen bezel
            PathArc {
                x: root.pillWidth + root.earRadius
                y: root.topExtension + root.pillHeight + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // Straight into right bezel extension
            PathLine {
                x: root.pillWidth + root.earRadius + root.rightBezelExtension
                y: root.topExtension + root.pillHeight + root.earRadius
            }
        }

        // CASE 3: Standard Interior Island (neither bottom ear)
        ShapePath {
            fillColor: "transparent"
            strokeColor: (!root.hasBottomLeftEar && !root.hasBottomRightEar) ? root.strokeColor : "transparent"
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            // Start in top-left extension
            startX: 0
            startY: 0

            // Straight down to top-left ear
            PathLine {
                x: 0
                y: root.topExtension
            }

            // Top-left concave ear
            PathArc {
                x: root.earRadius
                y: root.topExtension + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // Left wall
            PathLine {
                x: root.earRadius
                y: root.topExtension + root.pillHeight - root.bottomRadius
            }

            // Bottom-left convex corner
            PathArc {
                x: root.earRadius + root.bottomRadius
                y: root.topExtension + root.pillHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // Bottom edge
            PathLine {
                x: Math.max(root.earRadius + root.bottomRadius, root.pillWidth + root.earRadius - root.bottomRadius)
                y: root.topExtension + root.pillHeight
            }

            // Bottom-right convex corner
            PathArc {
                x: root.pillWidth + root.earRadius
                y: root.topExtension + root.pillHeight - root.bottomRadius
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // Right wall
            PathLine {
                x: root.pillWidth + root.earRadius
                y: root.topExtension + root.earRadius
            }

            // Top-right concave ear
            PathArc {
                x: root.pillWidth + 2 * root.earRadius
                y: root.topExtension
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // Straight up into top bezel extension
            PathLine {
                x: root.pillWidth + 2 * root.earRadius
                y: 0
            }
        }
    }
}
