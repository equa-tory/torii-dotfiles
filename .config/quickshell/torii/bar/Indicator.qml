import qs
import qs.widgets
import qs.services
import QtQuick
import QtQuick.Shapes

// One activity in the notch: a small circle with a glyph (and a ring that drains for timed things).
// Hover shows what it is; click turns it off. A reminder opens on click: time left, message and a cross to cancel.
Item {
    id: root

    property string key: ""
    property string glyph: ""
    property color tint: Theme.accent
    property real remain: -1              // 0..1 of the time left, -1 = no ring
    property string text: ""              // shown on hover
    property string detail: ""            // shown while open (reminders)
    property bool openable: false
    property bool closable: false         // cross inside the open text
    signal activated()
    signal closed()

    readonly property bool open: openable && Live.expanded === key
    readonly property bool shown: hover.hovered || open
    readonly property string caption: open ? detail : text

    implicitHeight: 22
    implicitWidth: pill.width

    Rectangle {
        id: pill
        height: 22
        radius: 11
        width: shown ? 22 + 8 + capLabel.implicitWidth + (open && closable ? 26 : 10) : 22
        color: shown ? Theme.surface : "transparent"
        clip: true
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }

        Item {
            id: circle
            width: 22
            height: 22

            Shape {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    strokeColor: Theme.surface2
                    strokeWidth: 2
                    fillColor: "transparent"
                    PathAngleArc { centerX: 11; centerY: 11; radiusX: 9; radiusY: 9; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: root.tint
                    strokeWidth: 2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 11; centerY: 11; radiusX: 9; radiusY: 9
                        startAngle: -90
                        sweepAngle: root.remain < 0 ? 360 : Math.max(2, 360 * root.remain)
                    }
                }
            }
            Glyph { anchors.centerIn: parent; text: root.glyph; size: 11; color: root.tint }
        }

        Label {
            id: capLabel
            x: 30
            anchors.verticalCenter: parent.verticalCenter
            text: root.caption
            color: Theme.fgDim
            font.pixelSize: Config.font.size - 2
            visible: root.shown
        }

        Glyph {
            visible: root.open && root.closable
            x: pill.width - 22
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.close
            size: 12
            color: root.overCross ? Theme.red : Theme.subtle
        }
    }

    HoverHandler { id: hover }
    readonly property bool overCross: open && closable && area.containsMouse && area.mouseX > pill.width - 28

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (root.overCross) root.closed();
            else if (root.openable) Live.expanded = root.open ? "" : root.key;
            else root.activated();
        }
    }
}
