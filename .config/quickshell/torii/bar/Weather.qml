import qs
import QtQuick
import qs.widgets
import qs.services

// Temperature in Celsius + icon. Dimmed when the data is stale, hidden when there is none. Click: forecast.
Item {
    id: root

    property bool open: false

    visible: Weather.available
    implicitWidth: wx.implicitWidth
    implicitHeight: 22

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

    MouseArea {
        x: -4; y: -4
        width: root.width + 8; height: root.height + 8
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("weather")
    }
}
