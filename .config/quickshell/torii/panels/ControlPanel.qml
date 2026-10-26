import qs
import qs.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

// Volume, Bluetooth, Network, background apps. Grows out of the notch.
Item {
    id: root

    implicitWidth: 380
    implicitHeight: Math.min(660, col.implicitHeight + 28)

    opacity: 0
    focus: true
    Component.onCompleted: { opacity = 1; forceActiveFocus(); }
    // arrows pick a background app, Enter opens it, Esc first lets go of the pick, then closes the panel
    Keys.onLeftPressed: tray.step(-1, 0)
    Keys.onRightPressed: tray.step(1, 0)
    Keys.onUpPressed: { if (tray.sel >= tray.cols) tray.step(0, -1); else tray.sel = -1; }
    Keys.onDownPressed: tray.step(0, 1)
    Keys.onReturnPressed: tray.activateSel()
    Keys.onEnterPressed: tray.activateSel()
    Keys.onEscapePressed: { if (tray.sel >= 0) tray.sel = -1; else Panels.close(); }
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 28
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            x: 16
            y: 4
            width: parent.width - 32
            spacing: 16

            // notifications: opens the launcher inside its Notifications menu; the badge is the unread count
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Item {
                    implicitWidth: 28
                    implicitHeight: 28
                    IconButton {
                        anchors.fill: parent
                        glyph: Notifs.dnd ? Icons.bellOff : Icons.bell
                        active: Notifs.badgeVisible
                        onClicked: Panels.openLauncherAt(["notifications"])
                    }
                    Rectangle {
                        visible: Notifs.badgeVisible
                        x: parent.width - width + 3
                        y: -3
                        width: Math.max(16, badgeText.implicitWidth + 8)
                        height: 16
                        radius: 8
                        color: Theme.accent
                        Label { id: badgeText; anchors.centerIn: parent; text: Notifs.unread > 99 ? "99+" : Notifs.unread; color: Theme.accentFg; font.pixelSize: 10 }
                    }
                }
            }

            AudioSection { Layout.fillWidth: true }
            BluetoothSection { Layout.fillWidth: true }
            NetworkSection { Layout.fillWidth: true }
            TraySection { id: tray; Layout.fillWidth: true }
        }
    }
}
