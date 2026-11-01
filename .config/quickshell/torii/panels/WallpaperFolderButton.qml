import qs
import qs.widgets
import QtQuick

Rectangle {
    property string text: ""
    property bool chosen: false
    property bool keyboardSelected: false
    property bool draggable: false
    property bool dropTarget: false
    signal dragStarted()
    signal dragMoved(real position)
    signal dragFinished()
    signal clicked()
    width: buttonText.implicitWidth + 24 + (draggable ? 14 : 0); height: 30; radius: 8
    border.width: keyboardSelected || dropTarget ? 1 : 0
    border.color: Theme.fg
    color: chosen ? Theme.accent : Theme.surface
    Label { id: buttonText; anchors.centerIn: parent; anchors.horizontalCenterOffset: parent.draggable ? 6 : 0; text: parent.text; color: parent.chosen ? Theme.accentFg : Theme.fgDim }
    MouseArea { anchors.fill: parent; anchors.leftMargin: parent.draggable ? 18 : 0; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    Label { x: 6; anchors.verticalCenter: parent.verticalCenter; visible: parent.draggable; text: "⋮"; color: Theme.muted }
    MouseArea {
        id: handle
        visible: parent.draggable
        width: 18; height: parent.height
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        preventStealing: true
        property bool moved: false
        property real origin: 0
        onPressed: mouse => { origin = mouse.x; moved = false; }
        onPositionChanged: mouse => {
            if (!pressed) return;
            if (!moved && Math.abs(mouse.x - origin) > 5) { moved = true; parent.dragStarted(); }
            if (moved) parent.dragMoved(mouse.x);
        }
        onReleased: { if (moved) parent.dragFinished(); else parent.clicked(); }
        onCanceled: { if (moved) parent.dragFinished(); }
    }
}
