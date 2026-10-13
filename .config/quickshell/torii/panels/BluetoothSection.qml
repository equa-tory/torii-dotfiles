import qs
import qs.services
import qs.widgets
import QtQuick
import QtQuick.Layouts

// Adapter power + scan, paired devices (connect / disconnect / forget) and newly found ones (pair).
Section {
    id: root

    title: "Bluetooth"
    visible: Bt.available

    // keep the delegates (and their hover/busy state) stable: only rebuild when the set or order changes
    property var shown: []
    readonly property string signature: Bt.devices.map(d => d.address + d.paired + d.connected).join("|")
    onSignatureChanged: shown = Bt.devices
    Component.onCompleted: shown = Bt.devices

    actions: [
        IconButton {
            visible: Bt.powered
            glyph: Icons.refresh
            size: 14
            active: Bt.scanning
            onClicked: Bt.setScanning(!Bt.scanning)
        },
        Toggle {
            checked: Bt.powered
            onToggled: on => Bt.setPowered(on)
        }
    ]

    Label {
        visible: !Bt.powered
        text: "Off"
        color: Theme.muted
        Layout.leftMargin: 10
    }

    Flickable {
        visible: Bt.powered
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 152)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 2

            Repeater {
                model: root.shown
                delegate: ListRow {
                    id: row
                    required property var modelData
                    readonly property var d: modelData

                    Layout.fillWidth: true
                    glyph: Icons[Bt.glyph(d)]
                    glyphColor: d.connected ? Theme.accent : Theme.subtle
                    title: d.name || d.address
                    titleColor: d.paired ? Theme.fg : Theme.fgDim
                    busy: d.pairing || d.state === 1
                    subtitle: d.pairing ? "Pairing…"
                            : d.state === 1 ? "Connecting…"
                            : d.connected ? "Connected" + (d.batteryAvailable ? "  ·  " + Math.round(d.battery * 100) + "%" : "")
                            : d.paired ? "Paired" : "Available"
                    onClicked: {
                        if (!d.paired) d.pair();
                        else if (d.connected) d.disconnect();
                        else d.connect();
                    }
                    IconButton {
                        visible: row.d.paired
                        glyph: Icons.trash
                        size: 14
                        onClicked: row.d.forget()
                    }
                }
            }

            Label {
                visible: Bt.scanning && root.shown.every(d => d.paired)
                text: "Searching…"
                color: Theme.muted
                Layout.leftMargin: 10
                Layout.topMargin: 2
            }
        }
    }
}
