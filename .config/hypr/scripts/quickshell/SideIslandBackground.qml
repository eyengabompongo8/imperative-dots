import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real pillWidth: parent ? parent.width : 0
    property real pillHeight: parent ? parent.height : 0
    property real earRadius: 14
    property real cornerRadius: 14

    property bool hasTopEar: true
    property bool hasBottomEar: true

    // Dynamically constrain radii if pillWidth is narrower than earRadius + cornerRadius
    readonly property real scaleFactor: (root.pillWidth > 0 && (root.earRadius + root.cornerRadius) > root.pillWidth)
        ? (root.pillWidth / (root.earRadius + root.cornerRadius))
        : 1.0

    readonly property real effectiveEar: root.earRadius * scaleFactor
    readonly property real effectiveCorner: Math.min(root.cornerRadius * scaleFactor, root.pillHeight > 0 ? root.pillHeight * 0.45 : root.cornerRadius)

    readonly property real topOffset: hasTopEar ? root.effectiveEar : 0
    readonly property real bottomOffset: hasBottomEar ? root.effectiveEar : 0

    property color fillColor: Qt.rgba(0.12, 0.12, 0.18, 0.75)
    property color strokeColor: Qt.rgba(1, 1, 1, 0.12)
    property real strokeWidth: 1.2

    anchors.top: parent ? parent.top : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    anchors.topMargin: -root.topOffset
    anchors.bottomMargin: -root.bottomOffset
    anchors.leftMargin: 0
    anchors.rightMargin: 0

    z: -1

    // Fill Shape (closed polygon)
    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        smooth: true
        visible: root.pillWidth > 0 && root.pillHeight > 0

        ShapePath {
            fillColor: root.fillColor
            strokeColor: "transparent"
            strokeWidth: 0

            // 1. Start on bezel at top ear tip (0, 0)
            startX: 0
            startY: 0

            // 2. Top-Left concave ear curving into top edge at (effectiveEar, effectiveEar)
            PathArc {
                x: root.effectiveEar
                y: root.topOffset
                radiusX: root.effectiveEar
                radiusY: root.effectiveEar
                direction: PathArc.Counterclockwise
            }

            // 3. Top horizontal edge to outer corner
            PathLine {
                x: Math.max(root.effectiveEar, root.pillWidth - root.effectiveCorner)
                y: root.topOffset
            }

            // 4. Top-Right convex corner curving into outer vertical wall
            PathArc {
                x: root.pillWidth
                y: root.topOffset + root.effectiveCorner
                radiusX: root.effectiveCorner
                radiusY: root.effectiveCorner
                direction: PathArc.Clockwise
            }

            // 5. Outer vertical wall
            PathLine {
                x: root.pillWidth
                y: Math.max(root.topOffset + root.effectiveCorner, root.topOffset + root.pillHeight - root.effectiveCorner)
            }

            // 6. Bottom-Right convex corner curving into bottom horizontal edge
            PathArc {
                x: Math.max(root.effectiveEar, root.pillWidth - root.effectiveCorner)
                y: root.topOffset + root.pillHeight
                radiusX: root.effectiveCorner
                radiusY: root.effectiveCorner
                direction: PathArc.Clockwise
            }

            // 7. Bottom horizontal edge back towards bezel
            PathLine {
                x: root.effectiveEar
                y: root.topOffset + root.pillHeight
            }

            // 8. Bottom-Left concave ear curving down to bezel
            PathArc {
                x: 0
                y: root.topOffset + root.pillHeight + root.effectiveEar
                radiusX: root.effectiveEar
                radiusY: root.effectiveEar
                direction: PathArc.Counterclockwise
            }

            // 9. Close along monitor bezel back to (0, 0)
            PathLine {
                x: 0
                y: 0
            }
        }
    }

    // Border Stroke Shape (open path: outlines floating perimeter and ears only, not along bezel)
    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        smooth: true
        visible: root.pillWidth > 0 && root.pillHeight > 0 && root.strokeWidth > 0 && root.strokeColor !== "transparent"

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            // Start on bezel at top ear tip (0, 0)
            startX: 0
            startY: 0

            // Top-Left concave ear
            PathArc {
                x: root.effectiveEar
                y: root.topOffset
                radiusX: root.effectiveEar
                radiusY: root.effectiveEar
                direction: PathArc.Counterclockwise
            }

            // Top horizontal edge
            PathLine {
                x: Math.max(root.effectiveEar, root.pillWidth - root.effectiveCorner)
                y: root.topOffset
            }

            // Top-Right convex corner
            PathArc {
                x: root.pillWidth
                y: root.topOffset + root.effectiveCorner
                radiusX: root.effectiveCorner
                radiusY: root.effectiveCorner
                direction: PathArc.Clockwise
            }

            // Outer vertical wall
            PathLine {
                x: root.pillWidth
                y: Math.max(root.topOffset + root.effectiveCorner, root.topOffset + root.pillHeight - root.effectiveCorner)
            }

            // Bottom-Right convex corner
            PathArc {
                x: Math.max(root.effectiveEar, root.pillWidth - root.effectiveCorner)
                y: root.topOffset + root.pillHeight
                radiusX: root.effectiveCorner
                radiusY: root.effectiveCorner
                direction: PathArc.Clockwise
            }

            // Bottom horizontal edge
            PathLine {
                x: root.effectiveEar
                y: root.topOffset + root.pillHeight
            }

            // Bottom-Left concave ear curving down to bezel
            PathArc {
                x: 0
                y: root.topOffset + root.pillHeight + root.effectiveEar
                radiusX: root.effectiveEar
                radiusY: root.effectiveEar
                direction: PathArc.Counterclockwise
            }
        }
    }
}
