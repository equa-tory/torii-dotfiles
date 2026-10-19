import qs
import Quickshell
import QtQuick
import qs.widgets

// Left click opens the calendar; right click swaps the time for the date inline, then back after a few seconds.
Item {
    id: root

    property bool showDate: false

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Label {
        id: label
        anchors.centerIn: parent
        text: root.showDate || Config.notch.clockDate ? Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
                            : Qt.formatDateTime(clock.date, "HH:mm")
        color: Theme.fg
        font.family: Config.font.family
        font.pixelSize: Config.font.size
        font.weight: Font.Medium
    }

    Timer {
        interval: 5000
        running: root.showDate
        onTriggered: root.showDate = false
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => { if (mouse.button === Qt.RightButton) root.showDate = !root.showDate; else Panels.toggle("calendar"); }
    }
}
