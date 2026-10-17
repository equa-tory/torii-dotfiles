pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import QtQuick

// 5-hour Claude usage for the signed-in account (torii-claude-usage). Only fetched while `watching`
// (the launcher is open), and only when ~/.claude/.credentials.json exists.
Singleton {
    id: root

    property bool watching: false
    property bool authed: false
    property real pct: -1                 // 0..100, -1 = unknown
    property real week: -1
    property string resets: ""
    readonly property bool ok: authed && pct >= 0

    // time until the 5-hour window resets
    property double clockMs: Date.now()
    readonly property real resetIn: resets !== "" && !isNaN(Date.parse(resets)) ? (Date.parse(resets) - clockMs) / 1000 : -1
    readonly property string resetText: {
        if (resetIn < 0) return "";
        const m = Math.ceil(resetIn / 60);
        if (m <= 0) return "soon";
        return m >= 60 ? Math.floor(m / 60) + "h " + String(m % 60).padStart(2, "0") + "m" : m + "m";
    }
    Timer { interval: 30000; running: root.watching; repeat: true; triggeredOnStart: true; onTriggered: root.clockMs = Date.now() }

    FileView {
        path: Config.home + "/.claude/.credentials.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.authed = true
        onLoadFailed: root.authed = false
    }

    Process {
        id: proc
        command: [Config.home + "/.config/torii/bin/torii-claude-usage"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.pct === undefined) return;
                    root.pct = d.pct; root.week = d.week; root.resets = d.resets;
                } catch (e) {}
            }
        }
    }

    function refresh() { if (authed && !proc.running) proc.running = true; }

    onWatchingChanged: if (watching) refresh()
    onAuthedChanged: if (watching) refresh()
    Timer { interval: 120000; running: root.watching; repeat: true; onTriggered: root.refresh() }
}
