import qs
import QtQuick

// Thin vertical slider, value 0..1 (full at the top). `moved` fires while dragging; the owner writes the value back.
Item {
    id: root

    property real value: 0
    property bool dim: false
    signal moved(real value)

    readonly property real shown: area.pressed ? drag : value
    property real drag: 0

    implicitWidth: 22
    implicitHeight: 110

    Rectangle {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        width: 6
        height: parent.height
        radius: 3
        color: Theme.overlay

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.max(track.width, track.height * Math.min(1, root.shown))
            radius: 3
            color: root.dim ? Theme.muted : Theme.accent
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
    Rectangle {
        width: 14
        height: 14
        radius: 7
        anchors.horizontalCenter: parent.horizontalCenter
        y: (root.height - height) * (1 - Math.min(1, root.shown))
        color: Theme.fg
        scale: area.pressed ? 1.15 : (area.containsMouse ? 1.05 : 1)
        Behavior on scale { NumberAnimation { duration: 100 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        function set(y) {
            root.drag = Math.max(0, Math.min(1, 1 - y / height));
            root.moved(root.drag);
        }
        onPressed: mouse => set(mouse.y)
        onPositionChanged: mouse => { if (pressed) set(mouse.y); }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.03 : -0.03))))
    }
}
