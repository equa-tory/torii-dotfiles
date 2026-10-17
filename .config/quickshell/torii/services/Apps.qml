pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import QtQuick

// Everything the launcher can start: desktop entries and mac-style apps (~/apps/<name>/app.json).
// No history is kept. Launching goes through `uwsm app` so apps become proper systemd units.
Singleton {
    id: root

    readonly property bool uwsm: Quickshell.env("UWSM_FINALIZE_VARNAMES") !== null
    property var portable: []

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
        const names = {};
        for (const e of DesktopEntries.applications.values) if (e.id.indexOf("torii-app-") !== 0) names[(e.name || "").toLowerCase()] = true;
        for (const e of DesktopEntries.applications.values) {
            if (e.id.indexOf("torii-app-") === 0) continue;           // generated from ~/apps, listed below as the folder itself
            out.push({ kind: "app", key: "app:" + e.id, name: e.name, sub: e.genericName || e.comment || "",
                       extra: (e.keywords || []).join(" "), icon: e.icon, id: e.id, wm: e.startupClass || "" });
        }
        for (const p of portable) {
            if (names[(p.name || "").toLowerCase()]) continue;      // the installed app already has its own entry
            out.push({ kind: "portable", key: "portable:" + p.dir, name: p.name, sub: p.description || "App",
                       extra: (p.keywords || []).join(" "), icon: p.icon, dir: p.dir, exec: p.exec });
        }
        return out;
    }

    // ---- launching
    function wrap(cmd) { return uwsm ? ["uwsm", "app", "--"].concat(cmd) : cmd; }

    function run(item) {
        if (item.kind === "app") {
            // torii-apps opens it (Terminal=true entries like cliamp run in kitty; uwsm's own terminal wrapper breaks with kitty)
            Quickshell.execDetached({ command: [Config.home + "/.config/torii/bin/torii-apps", "open", item.id], workingDirectory: Config.home });
        } else if (item.kind === "portable") {
            Quickshell.execDetached({ command: wrap(["sh", "-c", 'PATH="$PWD:$PATH"; exec ' + item.exec]), workingDirectory: item.dir });
        } else if (item.kind === "link") {
            Quickshell.execDetached({ command: wrap(["xdg-open", item.url]), workingDirectory: Config.home });
        }
    }
}
