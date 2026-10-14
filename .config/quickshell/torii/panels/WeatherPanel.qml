import qs
import qs.widgets
import qs.services
import QtQuick

// Forecast dropdown: now, the next hours (every 3 h) and the next days.
Item {
    id: root

    implicitWidth: 400
    implicitHeight: col.implicitHeight + 24

    opacity: 0
    Component.onCompleted: { opacity = 1; forceActiveFocus(); }
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    focus: true
    Keys.onEscapePressed: Panels.close()

    function deg(v) { return Math.round(v) + "°"; }

    Column {
        id: col
        x: 18; y: 4
        width: parent.width - 36
        spacing: 14

        Row {
            spacing: 14
            Label {
                text: Weather.glyph
                color: Theme.accent
                font.family: Config.font.family
                font.pixelSize: 34
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Label { text: root.deg(Weather.temp) + "  " + Weather.describe(Weather.code); font.pixelSize: Config.font.size + 3 }
                Label {
                    text: (Weather.city !== "" ? Weather.city + "  ·  " : "") + "wind " + Math.round(Weather.wind) + " km/h"
                    color: Theme.fgDim
                    font.pixelSize: Config.font.size - 1
                }
            }
        }

        Row {
            width: parent.width
            Repeater {
                model: Weather.hourly.slice(0, 8)
                Column {
                    width: col.width / 8
                    spacing: 3
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.hour; color: Theme.subtle; font.pixelSize: Config.font.size - 3 }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.glyphFor(modelData.code, parseInt(modelData.hour) >= 6 && parseInt(modelData.hour) < 20, 0)
                        color: Theme.accent
                        font.family: Config.font.family
                        font.pixelSize: Config.font.size + 4
                    }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.deg(modelData.temp); font.pixelSize: Config.font.size - 1 }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Column {
            width: parent.width
            spacing: 5
            Repeater {
                model: Weather.daily.slice(0, 6)
                Row {
                    width: col.width
                    height: 22
                    Label { width: 60; text: modelData.name; color: Theme.fgDim; anchors.verticalCenter: parent.verticalCenter }
                    Label {
                        width: 30
                        text: Weather.glyphFor(modelData.code, true, 0)
                        color: Theme.accent
                        font.family: Config.font.family
                        font.pixelSize: Config.font.size + 3
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label { width: 120; text: Weather.describe(modelData.code); color: Theme.subtle; font.pixelSize: Config.font.size - 1; anchors.verticalCenter: parent.verticalCenter }
                    Label { width: col.width - 210 - 40; text: root.deg(modelData.min); color: Theme.subtle; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                    Label { width: 40; text: root.deg(modelData.max); horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
