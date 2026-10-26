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

    // keyboard (the control panel forwards the keys): sel = the highlighted device
    property int sel: -1
    readonly property bool canNav: visible && Bt.powered && shown.length > 0
    function take(last) { sel = last ? shown.length - 1 : 0; }
    function release() { sel = -1; }
    function nav(k) {
        if (k === "up") { if (sel > 0) { sel--; return true; } return false; }
        if (k === "down") { if (sel < shown.length - 1) { sel++; return true; } return false; }
        if (k === "enter") {
            const d = shown[sel];
            if (!d) return true;
            if (!d.paired) { d.trusted = true; d.pair(); }
            else if (d.connected) d.disconnect();
            else { d.trusted = true; d.connect(); }
            return true;
        }
        return k === "left" || k === "right";
    }

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
                    required property int index
                    readonly property var d: modelData
                    current: index === root.sel

                    Layout.fillWidth: true
                    glyph: Icons[Bt.glyph(d)]
                    glyphColor: d.connected ? Theme.accent : Theme.subtle
                    title: d.name || d.address
                    titleColor: d.paired ? Theme.fg : Theme.fgDim
                    busy: d.pairing || (d.state === 1 && !d.connected)  // bluez can leave "connecting" set on a device that already works
                    subtitle: d.pairing ? "Pairing…"
                            : (d.state === 1 && !d.connected) ? "Connecting…"
                            : d.connected ? "Connected" + (Bt.level(d) >= 0 ? "  ·  " + Math.round(Bt.level(d) * 100) + "%" + (Bt.charging(d) ? " ⚡" : "") : "")
                            : d.paired ? "Paired" : "Available"
                    onClicked: {
                        // trusted: without it bluez (no agent here) refuses the audio profiles of headphones after pairing
                        if (!d.paired) { d.trusted = true; d.pair(); }
                        else if (d.connected) d.disconnect();
                        else { d.trusted = true; d.connect(); }
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
