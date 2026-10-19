pragma Singleton
import qs
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import qs.services.mock

// Adapter power/scan and the device list. Real BlueZ (Quickshell.Bluetooth), or fake devices with TORII_MOCK=1.
// Pairing is "just works" only: Quickshell has no PIN/passkey agent.
Singleton {
    id: root

    readonly property bool mock: Mock.on
    readonly property var adapter: Bluetooth.defaultAdapter

    // ---- mock state
    property bool mockPowered: true
    property bool mockScanning: false
    readonly property list<MockBtDevice> mockDevices: [
        MockBtDevice { name: "WH-1000XM5"; address: "AA:BB:CC:00:00:01"; icon: "audio-headphones"; paired: true; connected: true; batteryAvailable: true; battery: 0.82 },
        MockBtDevice { name: "MX Keys"; address: "AA:BB:CC:00:00:02"; icon: "input-keyboard"; paired: true; batteryAvailable: true; battery: 0.4 },
        MockBtDevice { name: "Pixel Buds Pro"; address: "AA:BB:CC:00:00:03"; icon: "audio-headset"; paired: true },
        MockBtDevice { name: "JBL Flip 6"; address: "AA:BB:CC:00:00:04"; icon: "audio-speakers" },
        MockBtDevice { name: "Galaxy S24"; address: "AA:BB:CC:00:00:05"; icon: "phone" }
    ]
    onMockScanningChanged: { for (const d of mockDevices) if (!d.paired) d.found = mockScanning; }

    // ---- uniform API
    readonly property bool available: mock || adapter !== null
    readonly property bool powered: mock ? mockPowered : (adapter ? adapter.enabled : false)
    readonly property bool scanning: mock ? mockScanning : (adapter ? adapter.discovering : false)

    // AirPods / Beats: BlueZ has no battery for them, torii-bt-battery asks them over Apple's own channel (AAP)
    JsonFetch { id: apple; command: [Quickshell.env("HOME") + "/.config/torii/bin/torii-bt-battery"] }
    readonly property var appleBattery: apple.data || ({})
    readonly property bool anyConnected: !mock && adapter !== null && adapter.devices.values.some(d => d.connected)
    onAnyConnectedChanged: if (anyConnected) appleRefresh.restart(); else apple.data = null
    Timer { id: appleRefresh; interval: 4000; onTriggered: apple.refresh() }
    Timer { interval: 90000; repeat: true; running: root.anyConnected; onTriggered: apple.refresh() }

    // battery 0..1 of a device (BlueZ's, or Apple's), -1 when unknown
    function level(d) {
        if (d.batteryAvailable) return d.battery;
        const a = appleBattery[d.address];
        return a ? a.level / 100 : -1;
    }
    function charging(d) { const a = appleBattery[d.address]; return !!(a && a.charging); }

    function rank(d) { return d.connected ? 0 : d.paired ? 1 : 2; }

    readonly property var devices: {
        let list = mock ? mockDevices.filter(d => d.paired || d.found)
                        : (adapter ? adapter.devices.values.filter(d => d.paired || d.bonded || d.name.length > 0) : []);
        return list.slice().sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name));
    }

    function setPowered(on) {
        if (mock) { mockPowered = on; if (!on) mockScanning = false; }
        else if (adapter) adapter.enabled = on;
    }
    function setScanning(on) {
        if (mock) mockScanning = on;
        else if (adapter) adapter.discovering = on;
    }

    // glyph for a device, by its icon name
    function glyph(d) {
        const i = d.icon || "";
        if (i.indexOf("headphone") >= 0 || i.indexOf("headset") >= 0) return "headphones";
        if (i.indexOf("speaker") >= 0) return "speaker";
        if (i.indexOf("keyboard") >= 0) return "keyboard";
        if (i.indexOf("mouse") >= 0) return "mouse";
        if (i.indexOf("phone") >= 0) return "phone";
        if (i.indexOf("computer") >= 0 || i.indexOf("laptop") >= 0) return "laptop";
        return "bluetooth";
    }
}
