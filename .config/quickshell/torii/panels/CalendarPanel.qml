import qs
import qs.widgets
import qs.services
import QtQuick

// Month calendar, Monday first. Arrows move the day, Page Up/Down the month, Home goes to today.
// `events` (date "YYYY-MM-DD" -> count) draws a dot under a day: the hook for a later calendar sync.
Item {
    id: root

    property var events: ({})
    property date today: new Date()
    property date cursor: new Date(today.getFullYear(), today.getMonth(), today.getDate())

    readonly property real cellW: 46
    readonly property real cellH: 34
    readonly property date first: new Date(cursor.getFullYear(), cursor.getMonth(), 1)
    readonly property int lead: (first.getDay() + 6) % 7                 // blanks before the 1st, Monday first
    readonly property int days: new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0).getDate()
    readonly property int weeks: Math.ceil((lead + days) / 7)

    implicitWidth: 7 * cellW + 36
    implicitHeight: 78 + weeks * cellH + 14

    opacity: 0
    focus: true
    Component.onCompleted: { opacity = 1; forceActiveFocus(); }
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    function go(days) { cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + days); }
    function month(d) {
        const day = Math.min(cursor.getDate(), new Date(cursor.getFullYear(), cursor.getMonth() + d + 1, 0).getDate());
        cursor = new Date(cursor.getFullYear(), cursor.getMonth() + d, day);
    }
    function key(y, m, d) { return y + "-" + String(m + 1).padStart(2, "0") + "-" + String(d).padStart(2, "0"); }

    Keys.onLeftPressed: go(-1)
    Keys.onRightPressed: go(1)
    Keys.onUpPressed: go(-7)
    Keys.onDownPressed: go(7)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_PageUp) { month(-1); event.accepted = true; }
        else if (event.key === Qt.Key_PageDown) { month(1); event.accepted = true; }
        else if (event.key === Qt.Key_Home) { cursor = new Date(today.getFullYear(), today.getMonth(), today.getDate()); event.accepted = true; }
    }
    Keys.onEscapePressed: Panels.close()

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => root.month(wheel.angleDelta.y > 0 ? -1 : 1)
    }

    Item {
        id: head
        x: 18; y: 2
        width: parent.width - 36
        height: 34
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.locale().monthName(root.cursor.getMonth()) + " " + root.cursor.getFullYear()
            font.pixelSize: Config.font.size + 3
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 4
            Repeater {
                model: [{ g: "‹", d: -1 }, { g: "›", d: 1 }]
                Rectangle {
                    width: 28; height: 26; radius: 8
                    color: ma.containsMouse ? Theme.surface2 : "transparent"
                    Label { anchors.centerIn: parent; text: modelData.g; color: Theme.fgDim; font.pixelSize: Config.font.size + 4 }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.month(modelData.d) }
                }
            }
        }
    }

    Row {
        x: 18; y: 40
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Label {
                width: root.cellW
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: index >= 5 ? Theme.muted : Theme.subtle
                font.pixelSize: Config.font.size - 2
            }
        }
    }

    Grid {
        x: 18; y: 66
        columns: 7
        Repeater {
            model: root.weeks * 7
            Item {
                readonly property int day: index - root.lead + 1
                readonly property bool inMonth: day >= 1 && day <= root.days
                readonly property bool isToday: inMonth && root.today.getFullYear() === root.cursor.getFullYear()
                    && root.today.getMonth() === root.cursor.getMonth() && root.today.getDate() === day
                readonly property bool sel: inMonth && day === root.cursor.getDate()
                width: root.cellW
                height: root.cellH

                Rectangle {
                    anchors.centerIn: parent
                    width: 32; height: 28; radius: 9
                    visible: parent.inMonth
                    color: parent.sel ? Theme.surface2 : "transparent"
                    border.width: parent.isToday ? 1.5 : 0
                    border.color: Theme.accent
                }
                Label {
                    anchors.centerIn: parent
                    visible: parent.inMonth
                    text: parent.day
                    color: parent.isToday ? Theme.accent : (index % 7 >= 5 ? Theme.fgDim : Theme.fg)
                }
                Rectangle {
                    visible: parent.inMonth && (root.events[root.key(root.cursor.getFullYear(), root.cursor.getMonth(), parent.day)] || 0) > 0
                    width: 4; height: 4; radius: 2
                    color: Theme.accent
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: parent.inMonth
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cursor = new Date(root.cursor.getFullYear(), root.cursor.getMonth(), parent.day)
                }
            }
        }
    }
}
