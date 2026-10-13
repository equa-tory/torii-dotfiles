pragma Singleton
import qs
import qs.widgets
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import qs.services.mock

// Physical connection (+ its IP) and the Wi-Fi list. NetworkManager through Quickshell.Networking,
// or fake networks with TORII_MOCK=1. Virtual devices (tun, tap, docker, virbr, lo) are never listed:
// only NetworkManager devices of type Wired/Wifi count.
Singleton {
    id: root

    readonly property bool mock: Mock.on

    // ---- real devices
    readonly property var devices: Networking.devices.values
    readonly property var wiredDev: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var wifiDev: devices.find(d => d.type === DeviceType.Wifi) ?? null

    // ---- mock state
    property bool mockEthernet: true
    readonly property list<MockNetwork> mockNetworks: [
        MockNetwork { name: "Home-5G"; signalStrength: 0.92; known: true; connected: true },
        MockNetwork { name: "Kitchen 2.4"; signalStrength: 0.64; known: true },
        MockNetwork { name: "CoffeeShop Guest"; signalStrength: 0.48; security: WifiSecurityType.Open },
        MockNetwork { name: "NETGEAR-72"; signalStrength: 0.33 },
        MockNetwork { name: "xfinitywifi"; signalStrength: 0.12 }
    ]
    Component.onCompleted: { for (const n of mockNetworks) n.peers = mockNetworks; refreshIp(); }
    property bool mockScanning: false
    Timer { id: mockScanTimer; interval: 2500; running: root.mockScanning; onTriggered: root.mockScanning = false }

    // ---- uniform API
    readonly property bool wifiAvailable: mock || wifiDev !== null
    readonly property bool scanning: mock ? mockScanning : (wifiDev ? wifiDev.scannerEnabled : false)

    readonly property var wifiNetworks: {
        const list = mock ? mockNetworks.slice() : (wifiDev ? wifiDev.networks.values.slice() : []);
        return list.sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength));
    }

    readonly property bool wiredUp: mock ? mockEthernet : (wiredDev !== null && wiredDev.connected)
    readonly property string wiredName: mock ? "enp0s1" : (wiredDev ? wiredDev.name : "")
    readonly property var connectedWifi: wifiNetworks.find(n => n.connected) ?? null

    // what the header shows: the physical connection that is up (wired wins, like the routing metric does)
    readonly property string activeKind: wiredUp ? "ethernet" : (connectedWifi ? "wifi" : "")
    readonly property string activeName: wiredUp ? wiredName : (connectedWifi ? connectedWifi.name : "")
    readonly property string activeDevice: wiredUp ? wiredName : (connectedWifi && wifiDev ? wifiDev.name : (mock ? "wlan0" : ""))

    property string ip: ""

    function secured(n) { return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe; }
    function strengthGlyph(n) { return Icons.wifiStrength[Math.min(3, Math.floor(n.signalStrength * 4))]; }

    function scan() {
        if (mock) { mockScanning = true; return; }
        if (!wifiDev) return;
        wifiDev.scannerEnabled = true;
        scanOff.restart();
    }
    Timer { id: scanOff; interval: 8000; onTriggered: if (root.wifiDev) root.wifiDev.scannerEnabled = false }

    // ---- IP of the physical device (never the tun one)
    onActiveDeviceChanged: refreshIp()
    onWiredUpChanged: refreshIp()
    function refreshIp() {
        if (mock) { ip = activeKind === "" ? "" : (activeKind === "wifi" ? "192.168.1.42" : "192.168.64.2"); return; }
        if (activeDevice === "") { ip = ""; return; }
        ipProc.command = ["ip", "-j", "-4", "addr", "show", "dev", activeDevice];
        ipProc.running = true;
    }
    Process {
        id: ipProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.ip = j.length && j[0].addr_info.length ? j[0].addr_info[0].local : "";
                } catch (e) { root.ip = ""; }
            }
        }
    }
    // DHCP can hand out the address after the state flips to connected
    Timer { interval: 3000; running: root.activeDevice !== "" && root.ip === ""; repeat: true; onTriggered: root.refreshIp() }
}
