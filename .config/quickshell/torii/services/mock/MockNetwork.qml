import QtQuick
import Quickshell.Networking

// Same surface as Quickshell.Networking WifiNetwork, for the VM.
QtObject {
    id: net

    property string name: ""
    property real signalStrength: 0.5
    property int security: WifiSecurityType.WpaPsk
    property bool known: false
    property bool connected: false
    property bool stateChanging: busy.running
    property string psk: "hunter22"

    signal connectionFailed(int reason)

    // set by Net so connecting here drops the other mock networks, like NetworkManager does
    property var peers: []

    property Timer busy: Timer {
        interval: 800
        onTriggered: {
            for (const p of net.peers) if (p !== net) p.connected = false;
            net.connected = true;
        }
    }

    function connect() {
        if (security !== WifiSecurityType.Open && !known) { connectionFailed(ConnectionFailReason.NoSecrets); return; }
        busy.restart();
    }
    function connectWithPsk(p) {
        if (p === psk) { known = true; busy.restart(); }
        else connectionFailed(ConnectionFailReason.WifiAuthTimeout);
    }
    function disconnect() { connected = false; }
    function forget() { connected = false; known = false; }
}
