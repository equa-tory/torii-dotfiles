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
    property int sel: -1                                  // chosen with the arrow keys; -1 = none
    readonly property int cols: Math.max(1, Math.floor((width - 4 + 6) / 42))
    readonly property string selTitle: sel >= 0 && sel < Tray.items.length ? (Tray.items[sel].title || Tray.items[sel].id) : ""
    // arrows: the first press picks the first app, then they move through the grid; false when there is nothing to move to
    function step(dx, dy) {
        const n = Tray.items.length;
        if (n === 0) return false;
        if (sel < 0) { sel = 0; return true; }
        sel = Math.max(0, Math.min(n - 1, sel + dx + dy * cols));
        return true;
    }
    function activateSel() {
        if (sel < 0 || sel >= Tray.items.length) return false;
        const it = Tray.items[sel];
        if (it.onlyMenu && it.hasMenu) { const c = flow.children[sel]; const p = c.mapToItem(null, c.width / 2, c.height); it.display(QsWindow.window, p.x, p.y); }
        else it.activate();
        return true;
    }

    title: "Background apps"
    visible: Tray.items.length > 0

    Flow {
        id: flow
        Layout.fillWidth: true
        Layout.leftMargin: 4
        spacing: 6

        Repeater {
            model: Tray.items
            delegate: Rectangle {
                id: cell
                required property var modelData
                required property int index

                width: 36
                height: 36
                radius: 10
                color: area.containsMouse || index === root.sel ? Theme.surface2 : Theme.surface
                border.width: index === root.sel ? 1 : 0
                border.color: Theme.accent
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
        visible: root.hovered !== "" || root.selTitle !== ""
        text: root.hovered !== "" ? root.hovered : root.selTitle
        color: Theme.subtle
        font.pixelSize: Config.font.size - 2
        Layout.leftMargin: 10
    }
}
