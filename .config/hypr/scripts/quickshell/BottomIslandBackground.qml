import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real pillWidth: parent ? parent.width : 0
    property real pillHeight: parent ? parent.height : 0
    property real earRadius: 14
    property real topRadius: 14

    property bool hasLeftEar: true
    property bool hasRightEar: true

    readonly property real leftOffset: hasLeftEar ? root.earRadius : 0
    readonly property real rightOffset: hasRightEar ? root.earRadius : 0

    property color fillColor: Qt.rgba(0.12, 0.12, 0.18, 0.75)
    property color strokeColor: Qt.rgba(1, 1, 1, 0.12)
    property real strokeWidth: 1.2

    anchors.top: parent ? parent.top : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    anchors.leftMargin: -root.leftOffset
    anchors.rightMargin: -root.rightOffset

    z: -1

    // Fill Shape (closed polygon)
    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        smooth: true

        ShapePath {
            fillColor: root.fillColor
            strokeColor: "transparent"
            strokeWidth: 0

            // 1. Start on bottom screen bezel at (0, H)
            startX: 0
            startY: root.pillHeight

            // 2. Bottom-Left concave ear curving up to (Re, H - Re)
            PathArc {
                x: root.earRadius
                y: root.pillHeight - root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Counterclockwise
            }

            // 3. Left vertical wall up to (Re, Rt)
            PathLine {
                x: root.earRadius
                y: root.topRadius
            }

            // 4. Top-Left convex corner curving to (Re + Rt, 0)
            PathArc {
                x: root.earRadius + root.topRadius
                y: 0
                radiusX: root.topRadius
                radiusY: root.topRadius
                direction: PathArc.Clockwise
            }

            // 5. Top horizontal edge to (W + Re - Rt, 0)
            PathLine {
                x: Math.max(root.earRadius + root.topRadius, root.pillWidth + root.earRadius - root.topRadius)
                y: 0
            }

            // 6. Top-Right convex corner curving to (W + Re, Rt)
            PathArc {
                x: root.pillWidth + root.earRadius
                y: root.topRadius
                radiusX: root.topRadius
                radiusY: root.topRadius
                direction: PathArc.Clockwise
            }

            // 7. Right vertical wall down to (W + Re, H - Re)
            PathLine {
                x: root.pillWidth + root.earRadius
                y: root.pillHeight - root.earRadius
            }

            // 8. Bottom-Right concave ear curving down to bottom bezel at (W + 2*Re, H)
            PathArc {
                x: root.pillWidth + 2 * root.earRadius
                y: root.pillHeight
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Counterclockwise
            }

            // 9. Close along bottom screen edge back to (0, H)
            PathLine {
                x: 0
                y: root.pillHeight
            }
        }
    }

    // Border Stroke Shape (open path: outlines floating top perimeter and ears)
    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        smooth: true
        visible: root.strokeWidth > 0 && root.strokeColor !== "transparent"

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            // Start at bottom-left ear (0, H)
            startX: 0
            startY: root.pillHeight

            // Bottom-left concave ear
            PathArc {
                x: root.earRadius
                y: root.pillHeight - root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Counterclockwise
            }

            // Left vertical wall
            PathLine {
                x: root.earRadius
                y: root.topRadius
            }

            // Top-left convex corner
            PathArc {
                x: root.earRadius + root.topRadius
                y: 0
                radiusX: root.topRadius
                radiusY: root.topRadius
                direction: PathArc.Clockwise
            }

            // Top horizontal edge
            PathLine {
                x: Math.max(root.earRadius + root.topRadius, root.pillWidth + root.earRadius - root.topRadius)
                y: 0
            }

            // Top-right convex corner
            PathArc {
                x: root.pillWidth + root.earRadius
                y: root.topRadius
                radiusX: root.topRadius
                radiusY: root.topRadius
                direction: PathArc.Clockwise
            }

            // Right vertical wall
            PathLine {
                x: root.pillWidth + root.earRadius
                y: root.pillHeight - root.earRadius
            }

            // Bottom-right concave ear
            PathArc {
                x: root.pillWidth + 2 * root.earRadius
                y: root.pillHeight
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Counterclockwise
            }
        }
    }
}
