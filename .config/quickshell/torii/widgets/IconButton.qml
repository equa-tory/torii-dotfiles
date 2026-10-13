import qs
import QtQuick

// Small round icon button (hover tint, optional accent).
Item {
    id: root

    property string glyph: ""
    property real size: 16
    property bool accent: false
    property bool active: false
    signal clicked()

    implicitWidth: 28
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: area.containsMouse ? Theme.overlay : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Glyph {
        anchors.centerIn: parent
        text: root.glyph
        size: root.size
        color: root.active || root.accent ? Theme.accent : (area.containsMouse ? Theme.fg : Theme.subtle)
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
