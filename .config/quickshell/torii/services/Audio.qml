pragma Singleton
import qs
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Default output/input volume, device lists and input level. Real PipeWire, or fake data with TORII_MOCK=1.
Singleton {
    id: root

    readonly property bool mock: Mock.on

    // set by the panel while it is visible, so the level meter costs nothing the rest of the time
    property bool watchLevel: false

    // ---- real nodes
    readonly property var sinkNode: Pipewire.defaultAudioSink
    readonly property var sourceNode: Pipewire.defaultAudioSource
    readonly property var sinkNodes: Pipewire.nodes.values.filter(n => !n.isStream && n.type === PwNodeType.AudioSink)
    readonly property var sourceNodes: Pipewire.nodes.values.filter(n => !n.isStream && n.type === PwNodeType.AudioSource)

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].concat(root.sinkNodes, root.sourceNodes)
    }
    PwNodePeakMonitor {
        node: root.sourceNode
        enabled: !root.mock && root.watchLevel && root.sourceNode !== null
        id: peak
    }

    // ---- mock state
    property real mockVolume: 0.62
    property bool mockMuted: false
    property real mockSourceVolume: 0.8
    property bool mockSourceMuted: false
    property string mockSink: "spk"
    property string mockSource: "mic"
    property real mockLevel: 0
    readonly property var mockSinks: [
        { key: "spk", label: "Built-in Speakers" },
        { key: "hdmi", label: "HDMI / DisplayPort 1" },
        { key: "bt", label: "WH-1000XM5 (Bluetooth)" }
    ]
    readonly property var mockSources: [
        { key: "mic", label: "Built-in Microphone" },
        { key: "usb", label: "USB Condenser Mic" }
    ]
    Timer {
        interval: 90
        running: root.mock && root.watchLevel
        repeat: true
        onTriggered: root.mockLevel = root.mockSourceMuted ? 0 : Math.max(0, 0.35 + 0.3 * Math.sin(Date.now() / 260) + (Math.random() - 0.5) * 0.3)
    }

    // ---- uniform API
    function label(n) { return n.description || n.nickname || n.name; }

    readonly property real volume: mock ? mockVolume : (sinkNode && sinkNode.audio ? sinkNode.audio.volume : 0)
    readonly property bool muted: mock ? mockMuted : (sinkNode && sinkNode.audio ? sinkNode.audio.muted : false)
    readonly property real sourceVolume: mock ? mockSourceVolume : (sourceNode && sourceNode.audio ? sourceNode.audio.volume : 0)
    readonly property bool sourceMuted: mock ? mockSourceMuted : (sourceNode && sourceNode.audio ? sourceNode.audio.muted : false)
    readonly property real level: mock ? mockLevel : (peak.enabled ? Math.min(1, peak.peak) : 0)
    readonly property bool available: mock || sinkNode !== null

    readonly property var sinks: mock
        ? mockSinks.map(d => ({ key: d.key, label: d.label, current: d.key === mockSink }))
        : sinkNodes.map(n => ({ key: n.name, label: label(n), current: sinkNode !== null && n.id === sinkNode.id }))
    readonly property var sources: mock
        ? mockSources.map(d => ({ key: d.key, label: d.label, current: d.key === mockSource }))
        : sourceNodes.map(n => ({ key: n.name, label: label(n), current: sourceNode !== null && n.id === sourceNode.id }))

    readonly property string sinkLabel: { const c = sinks.find(d => d.current); return c ? c.label : "No output"; }
    readonly property string sourceLabel: { const c = sources.find(d => d.current); return c ? c.label : "No input"; }

    function setVolume(v) {
        v = Math.max(0, Math.min(1, v));
        if (mock) mockVolume = v;
        else if (sinkNode && sinkNode.audio) sinkNode.audio.volume = v;
    }
    function toggleMute() {
        if (mock) mockMuted = !mockMuted;
        else if (sinkNode && sinkNode.audio) sinkNode.audio.muted = !sinkNode.audio.muted;
    }
    function toggleSourceMute() {
        if (mock) mockSourceMuted = !mockSourceMuted;
        else if (sourceNode && sourceNode.audio) sourceNode.audio.muted = !sourceNode.audio.muted;
    }
    function setSink(key) {
        if (mock) { mockSink = key; return; }
        const n = sinkNodes.find(x => x.name === key);
        if (n) Pipewire.preferredDefaultAudioSink = n;
    }
    function setSource(key) {
        if (mock) { mockSource = key; return; }
        const n = sourceNodes.find(x => x.name === key);
        if (n) Pipewire.preferredDefaultAudioSource = n;
    }
}
