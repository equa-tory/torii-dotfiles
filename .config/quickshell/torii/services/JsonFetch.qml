import Quickshell
import Quickshell.Io
import QtQuick

// Runs a command that prints JSON and keeps the result in `data`. `ensure()` fetches once per launcher opening.
Scope {
    id: root

    property var command: []
    property var data: null
    property bool fresh: false

    property bool killed: false            // a run was cut short by a newer refresh: its empty output must not wipe `data`
    // a refresh while the command still runs (Page Up/Down pressed quickly): stop it, start again a moment later
    function refresh() {
        fresh = true;
        if (proc.running) { killed = true; proc.running = false; restart.restart(); }
        else proc.running = true;
    }
    Timer { id: restart; interval: 30; onTriggered: proc.running = true }
    function ensure() { if (!fresh) refresh(); }
    function stale() { fresh = false; }

    Process {
        id: proc
        command: root.command
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.killed) { root.killed = false; if (text === "") return; }
                try { root.data = JSON.parse(text); } catch (e) { root.data = null; }
            }
        }
    }
}
