pragma Singleton
import qs
import Quickshell
import Quickshell.Hyprland
import QtQuick

// Open windows in the order they were last used (for Alt+Tab), and focusing one: on another workspace, minimised
// (the special:minimized workspace) or floating under others.
Singleton {
    id: root

    property var history: []          // addresses without 0x, most recent first
    property int index: 0             // selected card in the switcher

    function bare(a) { return String(a || "").replace(/^0x/, ""); }

    function minimised(t) {
        const w = t.lastIpcObject && t.lastIpcObject.workspace ? t.lastIpcObject.workspace.name : "";
        return String(w).indexOf("special:minimized") === 0;
    }

    readonly property var list: {
        const all = Hyprland.toplevels.values.filter(t => t.wayland !== null || t.lastIpcObject);
        const rank = a => { const i = root.history.indexOf(root.bare(a)); return i < 0 ? 1000 : i; };
        return all.slice().sort((a, b) => rank(a.address) - rank(b.address));
    }

    function touch(addr) {
        const a = bare(addr);
        if (a === "") return;
        const h = history.filter(x => x !== a);
        h.unshift(a);
        history = h.slice(0, 64);
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindowv2") root.touch(event.data);
            else if (event.name === "closewindow") root.history = root.history.filter(x => x !== root.bare(event.data));
        }
    }
    Component.onCompleted: {
        Hyprland.refreshToplevels();
        const act = Hyprland.activeToplevel;
        if (act) touch(act.address);
    }

    // step the selection: first call opens on the previous window, later ones move on
    function step(d) {
        const n = list.length;
        if (n === 0) return;
        if (Panels.panel !== "windows") {
            Hyprland.refreshToplevels();
            index = d > 0 ? Math.min(1, n - 1) : n - 1;
            Panels.open("windows");
        } else {
            index = (index + d + n) % n;
        }
    }

    function focus(t) {
        if (!t) return;
        const a = "0x" + bare(t.address);
        const sel = 'window="address:' + a + '"';
        let cmd = "";
        if (minimised(t)) {
            const ws = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
            cmd += "hyprctl dispatch 'hl.dsp.window.move({ workspace = " + ws + ", " + sel + ", follow = false })'; ";
        }
        cmd += "hyprctl dispatch 'hl.dsp.focus({ " + sel + " })'";
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function arrow(d) {
        if (Panels.panel !== "windows") return "no";
        step(d);
        return "ok";
    }

    // Alt+Q in the switcher: close the selected window (not the one that was focused before)
    function closeSelected() {
        if (Panels.panel !== "windows") return "no";
        const t = list[index];
        if (t) {
            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.window.close({ window = "address:0x' + bare(t.address) + '" })']);
            if (index >= list.length - 1) index = Math.max(0, index - 1);
            refreshLater.restart();
        }
        return "ok";
    }
    Timer { id: refreshLater; interval: 350; onTriggered: Hyprland.refreshToplevels() }
}
