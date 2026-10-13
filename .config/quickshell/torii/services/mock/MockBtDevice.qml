import QtQuick

// Same surface as Quickshell.Bluetooth BluetoothDevice, for the VM.
QtObject {
    id: dev

    property string name: ""
    property string address: ""
    property string icon: ""
    property bool paired: false
    property bool connected: false
    property bool pairing: false
    property bool batteryAvailable: false
    property real battery: 0
    property bool found: false          // only shows up while "scanning"
    property int state: connected ? 2 : (busy.running ? 1 : 0)

    property Timer busy: Timer {
        interval: 900
        onTriggered: {
            if (dev.pairing) { dev.pairing = false; dev.paired = true; dev.connected = true; }
            else dev.connected = !dev.connected;
        }
    }

    function connect() { if (!connected) busy.restart(); }
    function disconnect() { connected = false; }
    function pair() { pairing = true; busy.restart(); }
    function forget() { connected = false; paired = false; }
}
