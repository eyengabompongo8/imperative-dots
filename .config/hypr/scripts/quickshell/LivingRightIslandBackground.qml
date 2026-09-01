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

    // Unified diagonal animation progress from (xRight, topBarHeight)
    property real animProgress: root.isOpen ? 1.0 : 0.0
    Behavior on animProgress {
        NumberAnimation { duration: 280; easing.type: root.isOpen ? Easing.OutExpo : Easing.InCubic }
    }

    readonly property real animDropdownW: animProgress * widgetWidth
    readonly property real animDropdownH: animProgress * widgetHeight

    // Geometry anchors
    readonly property real currentBoxW: parent ? parent.width : pillWidth
    readonly property real currentBoxH: parent ? parent.height : topBarHeight

    readonly property real xRight: currentBoxW
    readonly property real xPillLeft: Math.max(0, currentBoxW - pillWidth)
    readonly property real xDropLeft: Math.max(0, currentBoxW - animDropdownW)
    readonly property real yBottom: topBarHeight + animDropdownH

    readonly property bool isWider: (root.isOpen || root.animDropdownW > 1) && (animDropdownW > (pillWidth + 4))
    readonly property bool isNarrower: (root.isOpen || root.animDropdownH > 1) && !isWider
    readonly property bool isCollapsed: !root.isOpen && root.animDropdownH <= 1 && root.animDropdownW <= 1

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

            startX: root.xPillLeft
            startY: 0

            // 1. Top-Left concave ear
            PathArc {
                x: root.xPillLeft + root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 2. Left vertical wall
            PathLine {
                x: root.xPillLeft + root.earRadius
                y: root.topBarHeight - root.bottomRadius
            }

            // 3. Bottom-Left convex corner
            PathArc {
                x: root.xPillLeft + root.earRadius + root.bottomRadius
                y: root.topBarHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 4. Bottom horizontal edge
            PathLine {
                x: root.xRight
                y: root.topBarHeight
            }

            // 5. Bottom-Right concave ear into right screen bezel
            PathArc {
                x: root.xRight + root.earRadius
                y: root.topBarHeight + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 6. Right vertical bezel edge up to top bezel
            PathLine {
                x: root.xRight + root.earRadius
                y: 0
            }

            // 7. Close along top screen bezel
            PathLine {
                x: root.xPillLeft
                y: 0
            }
        }

        // -------------------------------------------------------------
        // 2. CASE A FILL: Narrower Widget (W_anim <= W_pill)
        // -------------------------------------------------------------
        ShapePath {
            fillColor: root.isNarrower ? root.fillColor : "transparent"
            strokeColor: "transparent"
            strokeWidth: 0

            startX: root.xPillLeft
            startY: 0

            // 1. Pill Top-Left concave ear
            PathArc {
                x: root.xPillLeft + root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 2. Pill left vertical wall
            PathLine {
                x: root.xPillLeft + root.earRadius
                y: root.topBarHeight - root.bottomRadius
            }

            // 3. Pill bottom-left convex corner
            PathArc {
                x: root.xPillLeft + root.earRadius + root.bottomRadius
                y: root.topBarHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 4. Pill bottom horizontal edge to transition point at xDropLeft
            PathLine {
                x: Math.min(root.xRight, Math.max(root.xPillLeft + root.earRadius + root.bottomRadius, root.xDropLeft))
                y: root.topBarHeight
            }

            // 5. Widget top-left concave transition ear
            PathArc {
                x: Math.min(root.xRight, Math.max(root.xPillLeft + root.earRadius, root.xDropLeft + root.earRadius))
                y: root.topBarHeight + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 6. Widget left vertical wall
            PathLine {
                x: Math.min(root.xRight, Math.max(root.xPillLeft + root.earRadius, root.xDropLeft + root.earRadius))
                y: Math.max(root.topBarHeight + root.earRadius, root.yBottom - root.bottomRadius)
            }

            // 7. Widget bottom-left convex corner
            PathArc {
                x: Math.min(root.xRight, Math.max(root.xPillLeft + root.earRadius + root.bottomRadius, root.xDropLeft + root.earRadius + root.bottomRadius))
                y: root.yBottom
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 8. Widget bottom horizontal edge
            PathLine {
                x: root.xRight
                y: root.yBottom
            }

            // 9. Widget bottom-right concave ear into right bezel
            PathArc {
                x: root.xRight + root.earRadius
                y: root.yBottom + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 10. Right vertical bezel edge up to top
            PathLine {
                x: root.xRight + root.earRadius
                y: 0
            }

            // 11. Close along top screen bezel
            PathLine {
                x: root.xPillLeft
                y: 0
            }
        }

        // -------------------------------------------------------------
        // 3. CASE B FILL: Wider Widget (W_anim > W_pill)
        // -------------------------------------------------------------
        ShapePath {
            fillColor: root.isWider ? root.fillColor : "transparent"
            strokeColor: "transparent"
            strokeWidth: 0

            startX: root.xPillLeft
            startY: 0

            // 1. Pill top-left concave ear
            PathArc {
                x: root.xPillLeft + root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 2. Pill left vertical wall
            PathLine {
                x: root.xPillLeft + root.earRadius
                y: Math.max(root.earRadius, root.topBarHeight - root.earRadius)
            }

            // 3. Junction concave ear curving left into widget roof
            PathArc {
                x: root.xPillLeft
                y: root.topBarHeight
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 4. Widget top roof extending left to xDropLeft + Re + Rb
            PathLine {
                x: root.xDropLeft + root.earRadius + root.bottomRadius
                y: root.topBarHeight
            }

            // 5. Widget top-left convex corner
            PathArc {
                x: root.xDropLeft + root.earRadius
                y: root.topBarHeight + root.bottomRadius
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 6. Widget left vertical wall
            PathLine {
                x: root.xDropLeft + root.earRadius
                y: Math.max(root.topBarHeight + root.bottomRadius, root.yBottom - root.bottomRadius)
            }

            // 7. Widget bottom-left convex corner
            PathArc {
                x: root.xDropLeft + root.earRadius + root.bottomRadius
                y: root.yBottom
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 8. Widget bottom horizontal edge
            PathLine {
                x: root.xRight
                y: root.yBottom
            }

            // 9. Widget bottom-right concave ear into right bezel
            PathArc {
                x: root.xRight + root.earRadius
                y: root.yBottom + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 10. Right vertical bezel edge
            PathLine {
                x: root.xRight + root.earRadius
                y: 0
            }

            // 11. Close along top screen bezel
            PathLine {
                x: root.xPillLeft
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

            startX: root.xPillLeft
            startY: 0

            // Top-Left concave ear
            PathArc {
                x: root.xPillLeft + root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // Left vertical wall
            PathLine {
                x: root.xPillLeft + root.earRadius
                y: root.topBarHeight - root.bottomRadius
            }

            // Bottom-Left convex corner
            PathArc {
                x: root.xPillLeft + root.earRadius + root.bottomRadius
                y: root.topBarHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // Bottom horizontal edge
            PathLine {
                x: root.xRight
                y: root.topBarHeight
            }

            // Bottom-Right concave ear into right bezel
            PathArc {
                x: root.xRight + root.earRadius
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

            startX: root.xPillLeft
            startY: 0

            // 1. Pill Top-Left concave ear
            PathArc {
                x: root.xPillLeft + root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 2. Pill left vertical wall
            PathLine {
                x: root.xPillLeft + root.earRadius
                y: root.topBarHeight - root.bottomRadius
            }

            // 3. Pill bottom-left convex corner
            PathArc {
                x: root.xPillLeft + root.earRadius + root.bottomRadius
                y: root.topBarHeight
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 4. Pill bottom horizontal edge to transition point at xDropLeft
            PathLine {
                x: Math.min(root.xRight, Math.max(root.xPillLeft + root.earRadius + root.bottomRadius, root.xDropLeft))
                y: root.topBarHeight
            }

            // 5. Widget top-left concave transition ear
            PathArc {
                x: Math.min(root.xRight, Math.max(root.xPillLeft + root.earRadius, root.xDropLeft + root.earRadius))
                y: root.topBarHeight + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 6. Widget left vertical wall
            PathLine {
                x: Math.min(root.xRight, Math.max(root.xPillLeft + root.earRadius, root.xDropLeft + root.earRadius))
                y: Math.max(root.topBarHeight + root.earRadius, root.yBottom - root.bottomRadius)
            }

            // 7. Widget bottom-left convex corner
            PathArc {
                x: Math.min(root.xRight, Math.max(root.xPillLeft + root.earRadius + root.bottomRadius, root.xDropLeft + root.earRadius + root.bottomRadius))
                y: root.yBottom
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 8. Widget bottom horizontal edge
            PathLine {
                x: root.xRight
                y: root.yBottom
            }

            // 9. Widget bottom-right concave ear into right bezel
            PathArc {
                x: root.xRight + root.earRadius
                y: root.yBottom + root.earRadius
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

            startX: root.xPillLeft
            startY: 0

            // 1. Pill top-left concave ear
            PathArc {
                x: root.xPillLeft + root.earRadius
                y: root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 2. Pill left vertical wall
            PathLine {
                x: root.xPillLeft + root.earRadius
                y: Math.max(root.earRadius, root.topBarHeight - root.earRadius)
            }

            // 3. Junction concave ear
            PathArc {
                x: root.xPillLeft
                y: root.topBarHeight
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }

            // 4. Widget top roof
            PathLine {
                x: root.xDropLeft + root.earRadius + root.bottomRadius
                y: root.topBarHeight
            }

            // 5. Widget top-left convex corner
            PathArc {
                x: root.xDropLeft + root.earRadius
                y: root.topBarHeight + root.bottomRadius
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 6. Widget left vertical wall
            PathLine {
                x: root.xDropLeft + root.earRadius
                y: Math.max(root.topBarHeight + root.bottomRadius, root.yBottom - root.bottomRadius)
            }

            // 7. Widget bottom-left convex corner
            PathArc {
                x: root.xDropLeft + root.earRadius + root.bottomRadius
                y: root.yBottom
                radiusX: root.bottomRadius
                radiusY: root.bottomRadius
                direction: PathArc.Counterclockwise
            }

            // 8. Widget bottom horizontal edge
            PathLine {
                x: root.xRight
                y: root.yBottom
            }

            // 9. Widget bottom-right concave ear into right bezel
            PathArc {
                x: root.xRight + root.earRadius
                y: root.yBottom + root.earRadius
                radiusX: root.earRadius
                radiusY: root.earRadius
                direction: PathArc.Clockwise
            }
        }
    }
}
