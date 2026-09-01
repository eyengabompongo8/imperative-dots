import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real pillWidth: 350
    property real topBarHeight: 44
    property real widgetWidth: 450
    property real widgetHeight: 700
    property bool isOpen: false

    property real earRadius: 14
    property real bottomRadius: 14

    property color fillColor: Qt.rgba(0.12, 0.12, 0.18, 0.75)
    property color strokeColor: Qt.rgba(1, 1, 1, 0.12)
    property real strokeWidth: 1.2

    // Dynamic geometry driven by the animated parent box
    readonly property real currentBoxW: parent ? parent.width : pillWidth
    readonly property real currentBoxH: parent ? parent.height : topBarHeight

    readonly property bool isWider: currentBoxW > (pillWidth + 4)
    readonly property bool isNarrower: !isWider && (currentBoxH > (topBarHeight + 4))
    readonly property bool isCollapsed: !isWider && !isNarrower

    // Fixed pill left position: keeps the top pill 100% stationary on screen during width animations
    readonly property real pillLeftX: Math.max(0, currentBoxW - pillWidth)

    anchors.top: parent ? parent.top : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    anchors.leftMargin: -root.earRadius
    anchors.rightMargin: 0
    anchors.bottomMargin: -root.earRadius

    z: -1

    // Fill Shapes (Closed Polygons)
    Shape {
        anchors.fill: parent
        smooth: true

        // -------------------------------------------------------------
        // 1. COLLAPSED FILL: Standard Right Corner Pill
        // -------------------------------------------------------------
        ShapePath {
            fillColor: root.isCollapsed ? root.fillColor : "transparent"
            strokeColor: "transparent"
            strokeWidth: 0

            startX: 0
            startY: 0

            // 1. Top-Left concave ear to (Re, Re)
            PathArc {
                x: root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 2. Left vertical wall to (Re, topBarHeight - Rb)
            PathLine {
                x: root.earRadius
                y: root.topBarHeight - root.bottomRadius
            }

            // 3. Bottom-Left convex corner to (Re + Rb, topBarHeight)
            PathArc {
                x: root.earRadius + root.bottomRadius
                y: root.topBarHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 4. Bottom horizontal edge to (pillWidth, topBarHeight)
            PathLine {
                x: root.pillWidth
                y: root.topBarHeight
            }

            // 5. Bottom-Right concave ear into right screen bezel at (pillWidth + Re, topBarHeight + Re)
            PathArc {
                x: root.pillWidth + root.earRadius
                y: root.topBarHeight + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 6. Right vertical bezel edge up to (pillWidth + Re, 0)
            PathLine {
                x: root.pillWidth + root.earRadius
                y: 0
            }

            // 7. Close along top screen bezel to (0, 0)
            PathLine {
                x: 0
                y: 0
            }
        }

        // -------------------------------------------------------------
        // 2. CASE A FILL: Narrower Widget (W_widget <= W_pill)
        // -------------------------------------------------------------
        ShapePath {
            fillColor: root.isNarrower ? root.fillColor : "transparent"
            strokeColor: "transparent"
            strokeWidth: 0

            startX: 0
            startY: 0

            // 1. Pill Top-Left concave ear to (Re, Re)
            PathArc {
                x: root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 2. Pill left vertical wall to (Re, topBarHeight - Rb)
            PathLine {
                x: root.earRadius
                y: root.topBarHeight - root.bottomRadius
            }

            // 3. Pill bottom-left convex corner to (Re + Rb, topBarHeight)
            PathArc {
                x: root.earRadius + root.bottomRadius
                y: root.topBarHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 4. Pill bottom horizontal edge to transition point at (pillWidth - widgetWidth, topBarHeight)
            PathLine {
                x: Math.max(root.earRadius + root.bottomRadius, root.pillWidth - root.widgetWidth)
                y: root.topBarHeight
            }

            // 5. Widget top-left concave transition ear to (pillWidth - widgetWidth + Re, topBarHeight + Re)
            PathArc {
                x: Math.max(root.earRadius, root.earRadius + root.pillWidth - root.widgetWidth)
                y: root.topBarHeight + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 6. Widget left vertical wall to (pillWidth - widgetWidth + Re, currentBoxH - Rb)
            PathLine {
                x: Math.max(root.earRadius, root.earRadius + root.pillWidth - root.widgetWidth)
                y: root.currentBoxH - root.bottomRadius
            }

            // 7. Widget bottom-left convex corner to (pillWidth - widgetWidth + Re + Rb, currentBoxH)
            PathArc {
                x: Math.max(root.earRadius + root.bottomRadius, root.earRadius + root.pillWidth - root.widgetWidth + root.bottomRadius)
                y: root.currentBoxH
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 8. Widget bottom horizontal edge to (pillWidth, currentBoxH)
            PathLine {
                x: root.pillWidth
                y: root.currentBoxH
            }

            // 9. Widget bottom-right concave ear into right bezel at (pillWidth + Re, currentBoxH + Re)
            PathArc {
                x: root.pillWidth + root.earRadius
                y: root.currentBoxH + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 10. Right vertical bezel edge up to (pillWidth + Re, 0)
            PathLine {
                x: root.pillWidth + root.earRadius
                y: 0
            }

            // 11. Close along top screen bezel to (0, 0)
            PathLine {
                x: 0
                y: 0
            }
        }

        // -------------------------------------------------------------
        // 3. CASE B FILL: Wider Widget (W_widget > W_pill)
        // -------------------------------------------------------------
        ShapePath {
            fillColor: root.isWider ? root.fillColor : "transparent"
            strokeColor: "transparent"
            strokeWidth: 0

            // Start on top bezel at pillLeftX - top-left ear of the pill stays rock-solid on screen
            startX: root.pillLeftX
            startY: 0

            // 1. Pill top-left concave ear to (pillLeftX + Re, Re)
            PathArc {
                x: root.pillLeftX + root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 2. Pill left vertical wall to (pillLeftX + Re, topBarHeight - Re)
            PathLine {
                x: root.pillLeftX + root.earRadius
                y: Math.max(root.earRadius, root.topBarHeight - root.earRadius)
            }

            // 3. Junction concave ear to (pillLeftX, topBarHeight) curving left into widget roof
            PathArc {
                x: root.pillLeftX
                y: root.topBarHeight
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 4. Widget top roof extending left to (Re + Rb, topBarHeight)
            PathLine {
                x: root.earRadius + root.bottomRadius
                y: root.topBarHeight
            }

            // 5. Widget top-left convex corner to (Re, topBarHeight + Rb)
            PathArc {
                x: root.earRadius
                y: root.topBarHeight + root.bottomRadius
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 6. Widget left vertical wall to (Re, currentBoxH - Rb)
            PathLine {
                x: root.earRadius
                y: root.currentBoxH - root.bottomRadius
            }

            // 7. Widget bottom-left convex corner to (Re + Rb, currentBoxH)
            PathArc {
                x: root.earRadius + root.bottomRadius
                y: root.currentBoxH
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 8. Widget bottom horizontal edge to (currentBoxW, currentBoxH)
            PathLine {
                x: root.currentBoxW
                y: root.currentBoxH
            }

            // 9. Widget bottom-right concave ear into right bezel at (currentBoxW + Re, currentBoxH + Re)
            PathArc {
                x: root.currentBoxW + root.earRadius
                y: root.currentBoxH + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 10. Right vertical bezel edge up to (currentBoxW + Re, 0)
            PathLine {
                x: root.currentBoxW + root.earRadius
                y: 0
            }

            // 11. Close along top screen bezel to (pillLeftX, 0)
            PathLine {
                x: root.pillLeftX
                y: 0
            }
        }
    }

    // Border Strokes (Exposed Outer Perimeters Only)
    Shape {
        anchors.fill: parent
        smooth: true
        visible: root.strokeWidth > 0 && root.strokeColor !== "transparent"

        // -------------------------------------------------------------
        // 1. COLLAPSED STROKE
        // -------------------------------------------------------------
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.isCollapsed ? root.strokeColor : "transparent"
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            startX: 0
            startY: 0

            // Top-Left concave ear
            PathArc {
                x: root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // Left vertical wall
            PathLine {
                x: root.earRadius
                y: root.topBarHeight - root.bottomRadius
            }

            // Bottom-Left convex corner
            PathArc {
                x: root.earRadius + root.bottomRadius
                y: root.topBarHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // Bottom horizontal edge
            PathLine {
                x: root.pillWidth
                y: root.topBarHeight
            }

            // Bottom-Right concave ear into right bezel
            PathArc {
                x: root.pillWidth + root.earRadius
                y: root.topBarHeight + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }
        }

        // -------------------------------------------------------------
        // 2. CASE A STROKE (Narrower)
        // -------------------------------------------------------------
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.isNarrower ? root.strokeColor : "transparent"
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            startX: 0
            startY: 0

            // 1. Pill Top-Left concave ear
            PathArc {
                x: root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 2. Pill left vertical wall
            PathLine {
                x: root.earRadius
                y: root.topBarHeight - root.bottomRadius
            }

            // 3. Pill bottom-left convex corner
            PathArc {
                x: root.earRadius + root.bottomRadius
                y: root.topBarHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 4. Pill bottom horizontal edge
            PathLine {
                x: Math.max(root.earRadius + root.bottomRadius, root.pillWidth - root.widgetWidth)
                y: root.topBarHeight
            }

            // 5. Widget top-left concave transition ear
            PathArc {
                x: Math.max(root.earRadius, root.earRadius + root.pillWidth - root.widgetWidth)
                y: root.topBarHeight + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 6. Widget left vertical wall
            PathLine {
                x: Math.max(root.earRadius, root.earRadius + root.pillWidth - root.widgetWidth)
                y: root.currentBoxH - root.bottomRadius
            }

            // 7. Widget bottom-left convex corner
            PathArc {
                x: Math.max(root.earRadius + root.bottomRadius, root.earRadius + root.pillWidth - root.widgetWidth + root.bottomRadius)
                y: root.currentBoxH
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 8. Widget bottom horizontal edge
            PathLine {
                x: root.pillWidth
                y: root.currentBoxH
            }

            // 9. Widget bottom-right concave ear into right bezel
            PathArc {
                x: root.pillWidth + root.earRadius
                y: root.currentBoxH + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }
        }

        // -------------------------------------------------------------
        // 3. CASE B STROKE (Wider)
        // -------------------------------------------------------------
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.isWider ? root.strokeColor : "transparent"
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            startX: root.pillLeftX
            startY: 0

            // 1. Pill top-left concave ear
            PathArc {
                x: root.pillLeftX + root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 2. Pill left vertical wall
            PathLine {
                x: root.pillLeftX + root.earRadius
                y: Math.max(root.earRadius, root.topBarHeight - root.earRadius)
            }

            // 3. Junction concave ear
            PathArc {
                x: root.pillLeftX
                y: root.topBarHeight
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 4. Widget top roof
            PathLine {
                x: root.earRadius + root.bottomRadius
                y: root.topBarHeight
            }

            // 5. Widget top-left convex corner
            PathArc {
                x: root.earRadius
                y: root.topBarHeight + root.bottomRadius
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 6. Widget left vertical wall
            PathLine {
                x: root.earRadius
                y: root.currentBoxH - root.bottomRadius
            }

            // 7. Widget bottom-left convex corner
            PathArc {
                x: root.earRadius + root.bottomRadius
                y: root.currentBoxH
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 8. Widget bottom horizontal edge
            PathLine {
                x: root.currentBoxW
                y: root.currentBoxH
            }

            // 9. Widget bottom-right concave ear into right bezel
            PathArc {
                x: root.currentBoxW + root.earRadius
                y: root.currentBoxH + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }
        }
    }
}
