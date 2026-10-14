import qs
import QtQuick
import QtQuick.Shapes
import qs.widgets
import qs.services

// Temperature in Celsius + icon. Dimmed when the data is stale, hidden when there is none. Click: forecast.
// While the launcher is open the Claude usage ring sits next to it (when signed in).
Item {
    id: root

    property bool open: false
    property bool launcher: false

    visible: Weather.available
    implicitWidth: content.implicitWidth
    implicitHeight: 22

    MouseArea {
        x: -4; y: -4
        width: wx.width + 8; height: root.height + 8
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("weather")
    }

    Row {
        id: content
        spacing: 8
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: wx
            spacing: 5
            opacity: Weather.stale ? 0.5 : 1
            anchors.verticalCenter: parent.verticalCenter

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.glyph
                color: root.open ? Theme.fg : Theme.accent
                font.family: Config.font.family
                font.pixelSize: Config.font.size + 3
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(Weather.temp) + "°"
                color: Theme.fgDim
                font.family: Config.font.family
                font.pixelSize: Config.font.size
            }
        }

        Item {
            id: claude
            readonly property bool shown: root.launcher && ClaudeUsage.ok
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            width: shown ? 20 + 5 + pctLabel.implicitWidth : 0
            opacity: shown ? 1 : 0
            clip: true
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on opacity { NumberAnimation { duration: 160 } }

            readonly property color tint: ClaudeUsage.pct >= 85 ? Theme.red : Theme.accent

            Shape {
                id: ring
                width: 20; height: 20
                layer.enabled: true
                layer.samples: 4
                Connections { target: claude; function onTintChanged() { ring.layer.enabled = false; ring.layer.enabled = true; } }
                ShapePath {
                    strokeColor: Theme.surface2
                    strokeWidth: 2
                    fillColor: "transparent"
                    PathAngleArc { centerX: 10; centerY: 10; radiusX: 8; radiusY: 8; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: claude.tint
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
                font.pixelSize: Config.font.size
            }
        }
    }
}
