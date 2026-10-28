pragma Singleton
import qs
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// Programs that play sound, and what each one is set to (audio.appModes in config.json, by program name):
//   ""      normal
//   "mute"  silent always
//   "focus" silent while its window is not the focused one
Singleton {
    id: root

    readonly property var streams: (Pipewire.nodes.values || []).filter(n => n.isStream && n.type === PwNodeType.AudioOutStream
        && !((n.properties["media.name"] || "").startsWith("torii-")))
    PwObjectTracker { objects: root.streams }

    readonly property var modes: Config.audio.appModes || ({})
    function nameOf(n) { return n.properties["application.name"] || n.properties["node.name"] || n.name || "?"; }
    function modeOf(n) { return modes[nameOf(n)] || ""; }
    function nextMode(m) { return m === "" ? "mute" : (m === "mute" ? "focus" : ""); }

    function setMode(n, m) {
        const all = Object.assign({}, modes);
        if (m === "") delete all[nameOf(n)]; else all[nameOf(n)] = m;
        writer.command = [Quickshell.env("HOME") + "/.config/torii/bin/torii-config", "set", "audio.appModes", JSON.stringify(all)];
        writer.running = true;
        if (m === "" && n.audio) n.audio.muted = false;
    }
    Process { id: writer; onExited: apply.restart() }

    // is this program's window the focused one? (the same process, or the window class names the program)
    function focused(n) {
        const w = Hyprland.activeToplevel ? Hyprland.activeToplevel.lastIpcObject : null;
        if (!w || !w.class) return false;
        if (Number(n.properties["application.process.id"] || -1) === w.pid) return true;
        const cls = w.class.toLowerCase();
        return [n.properties["application.name"], n.properties["application.process.binary"]].some(s => {
            s = (s || "").toLowerCase().replace(/\.exe$/, "");
            return s.length > 2 && (cls.indexOf(s) >= 0 || s.indexOf(cls) >= 0);
        });
    }

    property var ours: ({})          // streams this service muted (by node id), so a program set back to normal is unmuted again
    function applyNow() {
        for (const n of streams) {
            const m = modeOf(n);
            if (!n.audio) continue;
            if (m === "") {
                if (ours[n.id] && n.audio.muted) n.audio.muted = false;
                delete ours[n.id];
                continue;
            }
            const want = m === "mute" ? true : !focused(n);
            if (n.audio.muted !== want) n.audio.muted = want;
            ours[n.id] = true;
        }
    }
    Timer { id: apply; interval: 150; onTriggered: root.applyNow() }
    onStreamsChanged: apply.restart()
    onModesChanged: apply.restart()
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "activewindowv2" || e.name === "closewindow") apply.restart(); }
    }
    function touch() {}
}
