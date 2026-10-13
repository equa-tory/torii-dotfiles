import qs
import QtQuick
import QtQuick.Layouts

// A selectable row: glyph, title (+ subtitle), optional trailing items.
Rectangle {
    id: root

    property string glyph: ""
    property color glyphColor: Theme.subtle
    property string title: ""
    property string subtitle: ""
    property color titleColor: Theme.fg
    property bool current: false
    property bool busy: false
    default property alias trailing: trail.data
    signal clicked()

    implicitHeight: 38
    radius: 10
    color: area.containsMouse ? Theme.surface2 : (current ? Theme.surface : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 10

        Glyph {
            text: root.glyph
            color: root.glyphColor
            Layout.preferredWidth: 20
            opacity: root.busy ? 0.5 : 1
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                text: root.title
                color: root.titleColor
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Theme.subtle
                font.pixelSize: Config.font.size - 3
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
        RowLayout {
            id: trail
            spacing: 2
        }
    }
}
