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

    // A window you could actually see and focus: mapped, not hidden, a real size, a name, on a normal workspace (or
    // special: the minimised ones and the scratchpad). Steam and other XWayland apps leave many invisible helpers.
    function real(t) {
        const o = t.lastIpcObject;
        if (!o || o.mapped !== true || o.hidden === true) return false;
        if (!o.size || o.size[0] < 2 || o.size[1] < 2) return false;
        if (!o["class"] && !o.title) return false;
        const w = o.workspace;
        if (!w) return false;
        return w.id > 0 || String(w.name).indexOf("special:") === 0;
    }

    readonly property var list: {
        const all = Hyprland.toplevels.values.filter(t => root.real(t));
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

    // Alt+Tab: the first Tab only picks the previous window and starts a short timer; the menu opens when Alt is still held
    // after it (or at the second Tab). Letting go of Alt before that switches at once, with no menu at all.
    property bool pending: false
    Timer { id: openTimer; interval: 160; onTriggered: { root.pending = false; if (root.list.length > 0) Panels.open("windows"); } }

    // The Tab and the Alt release of one Alt hold arrive as separate `qs ipc` calls with the same id, in either order.
    // A release that comes first (a very quick tap) is remembered by its id and applied by the Tab that follows it;
    // a release with no Tab left to wait for (the open switcher already took it) changes nothing.
    property string stepId: ""        // hold whose Tab was handled
    property string doneId: ""        // hold whose release arrived

    function step(d, id) {
        const n = list.length;
        if (n === 0) return;
        if (id && id !== stepId) {
            stepId = id;
            if (id === doneId && Panels.panel !== "windows" && !pending) {
                Hyprland.refreshToplevels();
                focus(list[d > 0 ? Math.min(1, n - 1) : n - 1]);
                return;
            }
        }
        if (Panels.panel === "windows") {
            index = (index + d + n) % n;
        } else if (pending) {
            openTimer.stop();
            pending = false;
            index = (index + d + n) % n;
            Panels.open("windows");
        } else {
            Hyprland.refreshToplevels();
            index = d > 0 ? Math.min(1, n - 1) : n - 1;
            pending = true;
            openTimer.restart();
        }
    }

    function commit(id) {
        if (id) doneId = id;
        if (pending) {
            openTimer.stop();
            pending = false;
            focus(list[index]);
        } else if (Panels.panel === "windows") {
            const t = list[index];
            Panels.close();
            focus(t);
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
