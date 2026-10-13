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
        function close(): void { Panels.close(); }
    }
    IpcHandler {
        target: "control"
        function toggle(): void { Panels.toggle("control"); }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { Panels.toggle("launcher"); }
    }
    IpcHandler {
        target: "switcher"
        function toggle(): void { Panels.toggle("switcher"); }
    }
}
