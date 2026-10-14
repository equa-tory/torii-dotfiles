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
