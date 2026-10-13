import qs
import QtQuick
import QtQuick.Layouts

// Section title row (small, muted) with room for trailing controls, followed by the content.
ColumnLayout {
    id: root

    property string title: ""
    default property alias content: body.data
    property alias actions: actionRow.data

    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 10
        Layout.rightMargin: 4
        spacing: 6

        Label {
            text: root.title.toUpperCase()
            color: Theme.muted
            font.pixelSize: Config.font.size - 3
            font.letterSpacing: 1.2
            font.weight: Font.Medium
            Layout.fillWidth: true
        }
        RowLayout { id: actionRow; spacing: 4 }
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: 2
    }
}
