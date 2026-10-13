import qs
import qs.services
import qs.widgets
import Quickshell
import QtQuick
import QtQuick.Layouts

// Background apps (Steam, v2rayN ...): left click opens/raises, right click shows the app's menu.
Section {
    id: root

    property string hovered: ""

    title: "Background apps"
    visible: Tray.items.length > 0

    Flow {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        spacing: 6

        Repeater {
            model: Tray.items
            delegate: Rectangle {
                id: cell
                required property var modelData

                width: 36
                height: 36
                radius: 10
                color: area.containsMouse ? Theme.surface2 : Theme.surface
                Behavior on color { ColorAnimation { duration: 120 } }

                Image {
                    id: img
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    sourceSize: Qt.size(40, 40)
                    source: cell.modelData.icon
                    visible: status === Image.Ready
                    smooth: true
                }
                Label {
                    anchors.centerIn: parent
                    visible: img.status !== Image.Ready
                    text: (cell.modelData.title || cell.modelData.id || "?").charAt(0).toUpperCase()
                    color: Theme.fgDim
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hovered = cell.modelData.title || cell.modelData.id
                    onExited: if (root.hovered === (cell.modelData.title || cell.modelData.id)) root.hovered = ""
                    onClicked: mouse => {
                        const it = cell.modelData;
                        if (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && it.onlyMenu)) {
                            if (it.hasMenu) {
                                const p = cell.mapToItem(null, mouse.x, mouse.y);
                                it.display(QsWindow.window, p.x, p.y);
                            }
                        } else if (mouse.button === Qt.MiddleButton) it.secondaryActivate();
                        else it.activate();
                    }
                }
            }
        }
    }

    Label {
        visible: root.hovered !== ""
        text: root.hovered
        color: Theme.subtle
        font.pixelSize: Config.font.size - 2
        Layout.leftMargin: 10
    }
}
