import qs
import qs.services
import qs.widgets
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

// The active physical connection with its IP, then the Wi-Fi list (hidden without Wi-Fi hardware).
Section {
    id: root

    title: "Network"

    property string asking: ""          // network name with an open password prompt
    property bool askFailed: false

    // stable delegates (a password field must not be rebuilt while typing)
    property var shown: []
    readonly property string signature: Net.wifiNetworks.map(n => n.name + n.connected + n.known).join("|")
    onSignatureChanged: if (asking === "") shown = Net.wifiNetworks
    onAskingChanged: if (asking === "") shown = Net.wifiNetworks
    Component.onCompleted: shown = Net.wifiNetworks

    actions: [
        IconButton {
            visible: Net.wifiAvailable
            glyph: Icons.refresh
            size: 14
            active: Net.scanning
            onClicked: Net.scan()
        }
    ]

    ListRow {
        Layout.fillWidth: true
        current: true
        glyph: Net.activeKind === "ethernet" ? Icons.ethernet
             : Net.activeKind === "wifi" && Net.connectedWifi ? Net.strengthGlyph(Net.connectedWifi) : Icons.wifiOff
        glyphColor: Net.activeKind === "" ? Theme.muted : Theme.accent
        title: Net.activeKind === "" ? "Not connected" : Net.activeName
        titleColor: Net.activeKind === "" ? Theme.muted : Theme.fg
        subtitle: Net.activeKind === "" ? "" : (Net.ip !== "" ? Net.ip : "Getting address…")
    }

    Flickable {
        id: flick
        visible: Net.wifiAvailable
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 160)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 2

            Repeater {
                model: root.shown
                delegate: ColumnLayout {
                    id: cell
                    required property var modelData
                    readonly property var n: modelData
                    readonly property bool prompting: root.asking === n.name

                    Layout.fillWidth: true
                    spacing: 2

                    // bring the password field into view (the list is height-capped and scrolls)
                    onPromptingChanged: if (prompting) reveal.start()
                    Timer {
                        id: reveal
                        interval: 30
                        onTriggered: flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height,
                                                                           cell.y + cell.height - flick.height + 6))
                    }

                    Connections {
                        target: cell.n
                        function onConnectionFailed(reason) {
                            // saved secrets missing or wrong password: ask (again)
                            root.askFailed = reason !== ConnectionFailReason.NoSecrets;
                            root.asking = cell.n.name;
                        }
                    }

                    ListRow {
                        Layout.fillWidth: true
                        glyph: Net.strengthGlyph(cell.n)
                        glyphColor: cell.n.connected ? Theme.accent : Theme.subtle
                        title: cell.n.name
                        titleColor: cell.n.connected ? Theme.fg : Theme.fgDim
                        busy: cell.n.stateChanging
                        subtitle: cell.n.stateChanging ? "Connecting…"
                                : cell.n.connected ? "Connected" : (cell.n.known ? "Saved" : "")
                        onClicked: {
                            if (cell.n.connected) { cell.n.disconnect(); return; }
                            if (cell.prompting) { root.asking = ""; return; }
                            root.askFailed = false;
                            if (!cell.n.known && Net.secured(cell.n)) root.asking = cell.n.name;
                            else cell.n.connect();
                        }
                        Glyph { visible: Net.secured(cell.n); text: Icons.lock; size: 12; color: Theme.muted }
                        IconButton {
                            visible: cell.n.known
                            glyph: Icons.trash
                            size: 14
                            onClicked: cell.n.forget()
                        }
                    }

                    PasswordField {
                        visible: cell.prompting
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        failed: root.askFailed
                        placeholder: root.askFailed ? "Couldn't connect, check the password" : "Password for " + cell.n.name
                        onAccepted: text => { root.askFailed = false; root.asking = ""; cell.n.connectWithPsk(text); }
                        onCancelled: root.asking = ""
                    }
                }
            }
        }
    }
}
