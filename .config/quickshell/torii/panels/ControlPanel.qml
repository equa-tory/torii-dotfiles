import qs
import qs.widgets
import QtQuick
import QtQuick.Layouts

// Volume, Bluetooth, Network, background apps. Grows out of the notch.
Item {
    id: root

    implicitWidth: 380
    implicitHeight: Math.min(660, col.implicitHeight + 28)

    opacity: 0
    Component.onCompleted: opacity = 1
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

            AudioSection { Layout.fillWidth: true }
            BluetoothSection { Layout.fillWidth: true }
            NetworkSection { Layout.fillWidth: true }
            TraySection { Layout.fillWidth: true }
        }
    }
}
