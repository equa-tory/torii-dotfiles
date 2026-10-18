import qs
import qs.services
import qs.widgets
import Quickshell
import Quickshell.Io
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

    // the "what is my IP" button: addresses of every interface that is up, and the public one (asked from the internet when pressed)
    property bool ipOpen: false
    property var localIps: []
    property string publicIp: ""
    function checkIp() {
        localIps = []; publicIp = "…";
        localProc.running = true;
        pubProc.running = true;
    }
    Process {
        id: localProc
        command: ["sh", "-c", "ip -4 -o addr show scope global | awk '{print $2, $4}'"]
        stdout: StdioCollector { onStreamFinished: root.localIps = text.trim().split("\n").filter(l => l !== "").map(l => l.split(" ")) }
    }
    Process {
        id: pubProc
        command: ["sh", "-c", "curl -fsS --max-time 5 https://api.ipify.org || echo unavailable"]
        stdout: StdioCollector { onStreamFinished: root.publicIp = text.trim() }
    }

    actions: [
        IconButton {
            glyph: Icons.web
            size: 14
            active: root.ipOpen
            onClicked: { root.ipOpen = !root.ipOpen; if (root.ipOpen) root.checkIp(); }
        },
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

    ColumnLayout {
        visible: root.ipOpen
        Layout.fillWidth: true
        spacing: 2

        Repeater {
            model: root.localIps
            delegate: ListRow {
                required property var modelData
                Layout.fillWidth: true
                glyph: modelData[0].indexOf("wl") === 0 ? Icons.wifiOff : Icons.ethernet
                title: modelData[1].split("/")[0]
                subtitle: modelData[0] + "  ·  click to copy"
                onClicked: Quickshell.execDetached(["wl-copy", modelData[1].split("/")[0]])
            }
        }
        ListRow {
            Layout.fillWidth: true
            glyph: Icons.web
            title: root.publicIp
            subtitle: "Public address  ·  click to copy"
            onClicked: if (root.publicIp !== "" && root.publicIp !== "…" && root.publicIp !== "unavailable") Quickshell.execDetached(["wl-copy", root.publicIp])
        }
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
