import Quickshell
import Quickshell.Io
import QtQuick

// Runs a command that prints JSON and keeps the result in `data`. `ensure()` fetches once per launcher opening.
Scope {
    id: root

    property var command: []
    property var data: null
    property bool fresh: false

    function refresh() { fresh = true; proc.running = false; proc.running = true; }
    function ensure() { if (!fresh) refresh(); }
    function stale() { fresh = false; }

    Process {
        id: proc
        command: root.command
        stdout: StdioCollector {
            onStreamFinished: { try { root.data = JSON.parse(text); } catch (e) { root.data = null; } }
        }
    }
}
