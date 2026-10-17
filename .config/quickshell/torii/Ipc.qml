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
        target: "windows"
        function next(): void { Windows.step(1); }
        function prev(): void { Windows.step(-1); }
        function commit(): void { Windows.commit(); }
        // the Alt+arrow and Alt+Q binds ask first: "ok" when the switcher took the key, "no" when it is not open
        function left(): string { return Windows.arrow(-1); }
        function right(): string { return Windows.arrow(1); }
        function close(): string { return Windows.closeSelected(); }
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
    IpcHandler {
        target: "text"
        function edit(action: string): void { Panels.editRequested(action); }
    }
}
