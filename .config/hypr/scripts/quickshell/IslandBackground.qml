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

    anchors.top: parent ? parent.top : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    anchors.leftMargin: -root.leftOffset
    anchors.rightMargin: -root.rightOffset
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

            // 1. Top-Left corner at (0, 0)
            startX: 0
            startY: 0

            // 2. Straight down left monitor bezel to (0, H + Re)
            PathLine {
                x: 0
                y: root.pillHeight + root.earRadius
            }

            // 3. Bottom-Left concave ear curving into bottom edge at (Re, H)
            PathArc {
                x: root.earRadius
                y: root.pillHeight
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 4. Bottom horizontal edge to (W - Rb, H)
            PathLine {
                x: Math.max(root.earRadius, root.pillWidth - root.bottomRadius)
                y: root.pillHeight
            }

            // 5. Bottom-Right convex corner to (W, H - Rb)
            PathArc {
                x: root.pillWidth
                y: root.pillHeight - root.bottomRadius
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 6. Right vertical wall to (W, Re)
            PathLine {
                x: root.pillWidth
                y: root.earRadius
            }

            // 7. Top-Right concave ear to (W + Re, 0)
            PathArc {
                x: root.pillWidth + root.earRadius
                y: 0
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 8. Close along top screen bezel to (0, 0)
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

            // 1. Top-Left start on top bezel at (0, 0)
            startX: 0
            startY: 0

            // 2. Top-Left concave ear to (Re, Re)
            PathArc {
                x: root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 3. Left vertical wall to (Re, H - Rb)
            PathLine {
                x: root.earRadius
                y: root.pillHeight - root.bottomRadius
            }

            // 4. Bottom-Left convex corner to (Re + Rb, H)
            PathArc {
                x: root.earRadius + root.bottomRadius
                y: root.pillHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 5. Bottom horizontal edge to (W, H)
            PathLine {
                x: Math.max(root.earRadius + root.bottomRadius, root.pillWidth)
                y: root.pillHeight
            }

            // 6. Bottom-Right concave ear curving to right screen bezel at (W + Re, H + Re)
            PathArc {
                x: root.pillWidth + root.earRadius
                y: root.pillHeight + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 7. Right vertical bezel edge up to top-right corner at (W + Re, 0)
            PathLine {
                x: root.pillWidth + root.earRadius
                y: 0
            }

            // 8. Close along top bezel to (0, 0)
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

            // 1. Top-Left start on top bezel at (0, 0)
            startX: 0
            startY: 0

            // 2. Top-Left concave ear to (Re, Re)
            PathArc {
                x: root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 3. Left vertical wall to (Re, H - Rb)
            PathLine {
                x: root.earRadius
                y: root.pillHeight - root.bottomRadius
            }

            // 4. Bottom-Left convex corner to (Re + Rb, H)
            PathArc {
                x: root.earRadius + root.bottomRadius
                y: root.pillHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 5. Bottom horizontal edge to (W + Re - Rb, H)
            PathLine {
                x: Math.max(root.earRadius + root.bottomRadius, root.pillWidth + root.earRadius - root.bottomRadius)
                y: root.pillHeight
            }

            // 6. Bottom-Right convex corner to (W + Re, H - Rb)
            PathArc {
                x: root.pillWidth + root.earRadius
                y: root.pillHeight - root.bottomRadius
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 7. Right vertical wall to (W + Re, Re)
            PathLine {
                x: root.pillWidth + root.earRadius
                y: root.earRadius
            }

            // 8. Top-Right concave ear to (W + 2*Re, 0)
            PathArc {
                x: root.pillWidth + 2 * root.earRadius
                y: 0
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 9. Close along top bezel to (0, 0)
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

            // Start at left monitor bezel at bottom-left ear (0, H + Re)
            startX: 0
            startY: root.pillHeight + root.earRadius

            // Bottom-left concave ear into bottom edge at (Re, H)
            PathArc {
                x: root.earRadius
                y: root.pillHeight
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // Bottom edge to (W - Rb, H)
            PathLine {
                x: Math.max(root.earRadius, root.pillWidth - root.bottomRadius)
                y: root.pillHeight
            }

            // Bottom-right convex corner to (W, H - Rb)
            PathArc {
                x: root.pillWidth
                y: root.pillHeight - root.bottomRadius
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // Right wall to (W, Re)
            PathLine {
                x: root.pillWidth
                y: root.earRadius
            }

            // Top-right concave ear to (W + Re, 0)
            PathArc {
                x: root.pillWidth + root.earRadius
                y: 0
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }
        }

        // CASE 2: Right Corner Pill (hasBottomRightEar)
        ShapePath {
            fillColor: "transparent"
            strokeColor: (root.hasBottomRightEar && !root.hasBottomLeftEar) ? root.strokeColor : "transparent"
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            // Start at top-left concave ear on top bezel (0, 0)
            startX: 0
            startY: 0

            // Top-left concave ear to (Re, Re)
            PathArc {
                x: root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // Left wall to (Re, H - Rb)
            PathLine {
                x: root.earRadius
                y: root.pillHeight - root.bottomRadius
            }

            // Bottom-left convex corner to (Re + Rb, H)
            PathArc {
                x: root.earRadius + root.bottomRadius
                y: root.pillHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // Bottom horizontal edge to (W, H)
            PathLine {
                x: Math.max(root.earRadius + root.bottomRadius, root.pillWidth)
                y: root.pillHeight
            }

            // Bottom-right concave ear to right screen bezel at (W + Re, H + Re)
            PathArc {
                x: root.pillWidth + root.earRadius
                y: root.pillHeight + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }
        }

        // CASE 3: Standard Interior Island (neither bottom ear)
        ShapePath {
            fillColor: "transparent"
            strokeColor: (!root.hasBottomLeftEar && !root.hasBottomRightEar) ? root.strokeColor : "transparent"
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            // Start at top-left concave ear (0, 0)
            startX: 0
            startY: 0

            // Top-left concave ear to (Re, Re)
            PathArc {
                x: root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // Left wall to (Re, H - Rb)
            PathLine {
                x: root.earRadius
                y: root.pillHeight - root.bottomRadius
            }

            // Bottom-left convex corner to (Re + Rb, H)
            PathArc {
                x: root.earRadius + root.bottomRadius
                y: root.pillHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // Bottom edge to (W + Re - Rb, H)
            PathLine {
                x: Math.max(root.earRadius + root.bottomRadius, root.pillWidth + root.earRadius - root.bottomRadius)
                y: root.pillHeight
            }

            // Bottom-right convex corner to (W + Re, H - Rb)
            PathArc {
                x: root.pillWidth + root.earRadius
                y: root.pillHeight - root.bottomRadius
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // Right wall to (W + Re, Re)
            PathLine {
                x: root.pillWidth + root.earRadius
                y: root.earRadius
            }

            // Top-right concave ear to (W + 2*Re, 0)
            PathArc {
                x: root.pillWidth + 2 * root.earRadius
                y: 0
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }
        }
    }
}
