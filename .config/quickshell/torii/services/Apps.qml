pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import QtQuick

// Everything the launcher can start: desktop entries, mac-style apps (~/apps/<name>/app.json), quicklinks,
// plus a recency log. Launching goes through `uwsm app` so apps become proper systemd units.
Singleton {
    id: root

    readonly property bool uwsm: Quickshell.env("UWSM_FINALIZE_VARNAMES") !== null
    property var portable: []
    property var recents: ({})            // key -> { count, last }

    readonly property string recentPath: Config.stateDir + "/launcher-recent.json"

    // ---- sources
    function refresh() { scan.running = true; }

    Process {
        id: scan
        command: [Config.home + "/.config/torii/bin/torii-apps", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.portable = JSON.parse(text); } catch (e) { root.portable = []; }
            }
        }
    }

    function items() {
        const out = [];
        for (const e of DesktopEntries.applications.values) {
            out.push({ kind: "app", key: "app:" + e.id, name: e.name, sub: e.genericName || e.comment || "",
                       extra: (e.keywords || []).join(" "), icon: e.icon, id: e.id });
        }
        for (const p of portable) {
            out.push({ kind: "portable", key: "portable:" + p.dir, name: p.name, sub: p.description || "App",
                       extra: (p.keywords || []).join(" "), icon: p.icon, dir: p.dir, exec: p.exec });
        }
        out.push({ kind: "action", key: "action:quicklinks", name: "Edit quicklinks", sub: Quicklinks.path,
                   extra: "quicklinks links keywords bookmarks", icon: "", action: "quicklinks" });
        return out;
    }

    // ---- launching
    function wrap(cmd) { return uwsm ? ["uwsm", "app", "--"].concat(cmd) : cmd; }

    function run(item) {
        if (item.kind === "app") {
            const entry = DesktopEntries.byId(item.id);
            if (uwsm) Quickshell.execDetached({ command: ["uwsm", "app", "--", item.id + ".desktop"], workingDirectory: Config.home });
            else if (entry) entry.execute();
        } else if (item.kind === "portable") {
            Quickshell.execDetached({ command: wrap(["sh", "-c", 'PATH="$PWD:$PATH"; exec ' + item.exec]), workingDirectory: item.dir });
        } else if (item.kind === "link") {
            Quickshell.execDetached({ command: wrap(["xdg-open", item.url]), workingDirectory: Config.home });
        } else if (item.kind === "action" && item.action === "quicklinks") {
            Quickshell.execDetached({ command: wrap(["kitty", "nvim", Quicklinks.path]), workingDirectory: Config.home });
        }
        touch(item.key);
    }

    // ---- recents
    function touch(key) {
        if (key === undefined || key === "") return;
        const r = Object.assign({}, recents);
        const cur = r[key] || { count: 0, last: 0 };
        r[key] = { count: cur.count + 1, last: Date.now() };
        recents = r;
        store.setText(JSON.stringify(r));
    }

    // bonus added to a match score: recent and frequent apps float up
    function boost(key) {
        const r = recents[key];
        if (!r) return 0;
        const ageDays = (Date.now() - r.last) / 86400000;
        return 120 * Math.exp(-ageDays / 10) + Math.min(r.count, 20) * 4;
    }

    FileView {
        id: store
        path: root.recentPath
        printErrors: false
        onLoaded: { try { root.recents = JSON.parse(text()); } catch (e) {} }
    }
}
