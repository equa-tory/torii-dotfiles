import Quickshell
import Quickshell.Io
import QtQuick

// qs -c torii ipc call <target> <function>
Scope {
    IpcHandler {
        target: "shell"
        function reload(): void { Quickshell.reload(true); }
    }
    IpcHandler {
        target: "panels"
        function close(): void { State.close(); }
    }
    IpcHandler {
        target: "control"
        function toggle(): void { State.toggle("control"); }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { State.toggle("launcher"); }
    }
    IpcHandler {
        target: "switcher"
        function toggle(): void { State.toggle("switcher"); }
    }
}
