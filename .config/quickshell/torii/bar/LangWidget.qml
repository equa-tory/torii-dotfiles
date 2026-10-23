import qs
import QtQuick
import qs.widgets
import qs.services

// Current keyboard layout (EN / RU), always shown. Click switches to the next layout.
Item {
    id: root

    readonly property bool present: Lang.code !== ""
    visible: present
    implicitWidth: label.implicitWidth
    implicitHeight: 22

    Label {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: Lang.code
        color: ma.containsMouse ? Theme.accent : Theme.fgDim
        font.pixelSize: Config.font.size - 1
        font.weight: Font.Medium
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    MouseArea {
        id: ma
        x: -4; y: 0
        width: root.width + 8; height: root.height
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Lang.next()
    }
}
