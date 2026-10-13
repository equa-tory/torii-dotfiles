import qs
import QtQuick

// Thin horizontal slider, value 0..1. `moved` fires while dragging; the owner writes the value back.
Item {
    id: root

    property real value: 0
    property bool dim: false
    signal moved(real value)

    readonly property real shown: area.pressed ? drag : value
    property real drag: 0

    implicitHeight: 22

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.overlay

        Rectangle {
            width: Math.max(track.height, track.width * Math.min(1, root.shown))
            height: parent.height
            radius: 3
            color: root.dim ? Theme.muted : Theme.accent
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
    Rectangle {
        width: 14
        height: 14
        radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: (root.width - width) * Math.min(1, root.shown)
        color: Theme.fg
        scale: area.pressed ? 1.15 : (area.containsMouse ? 1.05 : 1)
        Behavior on scale { NumberAnimation { duration: 100 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        function set(x) {
            root.drag = Math.max(0, Math.min(1, x / width));
            root.moved(root.drag);
        }
        onPressed: mouse => set(mouse.x)
        onPositionChanged: mouse => { if (pressed) set(mouse.x); }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.03 : -0.03))))
    }
}
