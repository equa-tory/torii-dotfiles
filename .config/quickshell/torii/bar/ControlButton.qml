import qs
import QtQuick
import qs.widgets

// The single glyph that opens the control panel.
Item {
    id: root

    property bool open: false

    implicitWidth: 18
    implicitHeight: 18

    Label {
        anchors.centerIn: parent
        text: ""
        color: root.open ? Theme.accent : Theme.subtle
        font.family: Config.font.family
        font.pixelSize: 11
        rotation: root.open ? 180 : 0

        Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("control")
    }
}
