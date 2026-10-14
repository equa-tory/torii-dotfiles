import qs
import QtQuick
import QtQuick.Shapes
import qs.widgets
import qs.services

// Claude 5-hour usage: a ring and the percentage. Shown by the widget slot while the launcher is open.
Item {
    id: root

    property bool shown: false
    readonly property bool active: shown && ClaudeUsage.ok
    readonly property color tint: ClaudeUsage.pct >= 85 ? Theme.red : Theme.accent

    height: 20
    width: active ? 20 + 5 + pctLabel.implicitWidth : 0
    opacity: active ? 1 : 0
    visible: width > 0.5
    clip: true
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Shape {
        id: ring
        width: 20; height: 20
        layer.enabled: true
        layer.samples: 4
        Connections { target: root; function onTintChanged() { ring.layer.enabled = false; ring.layer.enabled = true; } }
        ShapePath {
            strokeColor: Theme.surface2
            strokeWidth: 2
            fillColor: "transparent"
            PathAngleArc { centerX: 10; centerY: 10; radiusX: 8; radiusY: 8; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: root.tint
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: 10; centerY: 10; radiusX: 8; radiusY: 8
                startAngle: -90
                sweepAngle: Math.max(3, 3.6 * Math.max(0, ClaudeUsage.pct))
            }
        }
    }
    Label {
        id: pctLabel
        x: 25
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(ClaudeUsage.pct) + "%"
        color: Theme.fgDim
    }
}
