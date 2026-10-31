pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import QtQuick

// ChatGPT-plan Codex allowance, fetched only while its notch widget is shown.
Singleton {
    id: root

    property bool watching: false
    property real pct: -1
    property real week: -1
    property string resets: ""
    property string weekResets: ""
    readonly property bool ok: pct >= 0
    property double fetchedAt: 0
    property double clockMs: Date.now()
    readonly property real resetIn: resets !== "" && !isNaN(Date.parse(resets)) ? (Date.parse(resets) - clockMs) / 1000 : -1
    readonly property string resetText: {
        if (resetIn < 0) return "";
        const m = Math.ceil(resetIn / 60);
        if (m <= 0) return "soon";
        return m >= 60 ? Math.floor(m / 60) + "h " + String(m % 60).padStart(2, "0") + "m" : m + "m";
    }
    Timer { interval: 30000; running: root.watching; repeat: true; triggeredOnStart: true; onTriggered: root.clockMs = Date.now() }

    Process {
        id: proc
        command: [Config.home + "/.config/torii/bin/torii-codex-usage"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try { d = JSON.parse(text); } catch (e) {}
                root.pct = typeof d.pct === "number" ? d.pct : -1;
                root.week = typeof d.week === "number" ? d.week : -1;
                root.resets = d.resets || "";
                root.weekResets = d.weekResets || "";
                root.fetchedAt = Date.now();
            }
        }
    }

    function refresh() {
        if (!proc.running && Date.now() - fetchedAt >= 120000) proc.running = true;
    }
    onWatchingChanged: if (watching) refresh()
    Timer { interval: 120000; running: root.watching; repeat: true; onTriggered: root.refresh() }
}
