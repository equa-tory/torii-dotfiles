pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import QtQuick

// CPU / RAM / GPU load and temperatures (torii-sys). Polled every 2 s, and only while a widget shows them.
Singleton {
    id: root

    property bool watching: false
    property var stats: ({})
    readonly property bool ok: stats.cpu !== undefined

    Process {
        id: proc
        command: [Config.home + "/.config/torii/bin/torii-sys", "stats"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.stats = JSON.parse(text); } catch (e) {} }
        }
    }
    function refresh() { if (!proc.running) proc.running = true; }
    onWatchingChanged: if (watching) refresh()
    Timer { interval: 2000; running: root.watching; repeat: true; onTriggered: root.refresh() }
}
