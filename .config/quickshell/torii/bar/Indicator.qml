import qs
import qs.widgets
import qs.services
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

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
    property string image: ""             // cover shown in the circle instead of the glyph
    property Component content: null      // custom body while open (the media controls)
    property real contentWidth: 0
    signal activated()
    signal closed()

    readonly property bool open: openable && Live.expanded === key
    readonly property bool shown: hover.hovered || open
    readonly property string caption: open ? detail : text

    // "circles" style: every activity sits on its own round backing of the notch colour
    property real pad: 0
    property color backing: "transparent"
    implicitHeight: 22 + 2 * pad
    implicitWidth: pill.width + 2 * pad

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.backing
    }

    Rectangle {
        id: pill
        x: root.pad
        y: (root.implicitHeight - height) / 2
        height: open && content ? 26 : 22
        radius: height / 2
        width: open && content ? 22 + 8 + contentWidth + 10 : shown ? 22 + 8 + capLabel.implicitWidth + (open && closable ? 26 : 10) : 22
        color: shown ? Theme.surface : "transparent"
        clip: true
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }

        Item {
            id: circle
            width: 22
            height: 22
            y: (pill.height - height) / 2

            Shape {
                id: ring
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4
                // repaint when the theme colour changes (a cached layer could otherwise keep the old colour)
                Connections { target: root; function onTintChanged() { ring.layer.enabled = false; ring.layer.enabled = true; } }
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
            Image {
                id: cover
                anchors.centerIn: parent
                width: 16; height: 16
                visible: root.image !== "" && status === Image.Ready
                source: root.image
                sourceSize: Qt.size(32, 32)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: coverMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1 }
            }
            Rectangle { id: coverMask; width: 16; height: 16; radius: 8; visible: false; layer.enabled: true }
            Glyph { anchors.centerIn: parent; visible: !cover.visible; text: root.glyph; size: 11; color: root.tint }
        }

        Label {
            id: capLabel
            x: 30
            anchors.verticalCenter: parent.verticalCenter
            text: root.caption
            color: Theme.fgDim
            font.pixelSize: Config.font.size - 2
            visible: root.shown && !(root.open && root.content)
        }

        Loader {
            x: 30
            z: 10
            width: root.contentWidth
            height: pill.height
            active: root.open && root.content !== null
            sourceComponent: root.content
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
    readonly property bool overCross: open && closable && area.containsMouse && area.mouseX - root.pad > pill.width - 28

    MouseArea {
        id: area
        anchors.fill: parent
        z: -1                                   // controls inside an open activity get the clicks first
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (root.overCross) root.closed();
            else if (root.openable) Live.expanded = root.open ? "" : root.key;
            else root.activated();
        }
    }
}
