import qs
import QtQuick
import qs.widgets
import qs.services

// Temperature in Celsius + icon. Dimmed when the data is stale, hidden when there is none.
Row {
    id: root

    visible: Weather.available
    spacing: 5
    opacity: Weather.stale ? 0.5 : 1

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: Weather.glyph
        color: Theme.accent
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
