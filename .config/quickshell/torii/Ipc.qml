import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

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
    IpcHandler {
        target: "notifs"
        function dnd(): void { Notifs.toggleDnd(); }
        function clear(): void { Notifs.clear(); }
    }
    IpcHandler {
        target: "media"
        function toggle(): void { Media.toggle(); }
        function next(): void { Media.next(); }
        function previous(): void { Media.previous(); }
        function seek(seconds: int): void { Media.seekBy(seconds); }
    }
}
