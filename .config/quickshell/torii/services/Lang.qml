pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// The keyboard layout that is active now (from Hyprland's `activelayout` event), as a two letter code.
Singleton {
    id: root

    property string name: ""
    readonly property string code: {
        const n = name.toLowerCase();
        if (n === "") return "";
        if (n.indexOf("russian") >= 0) return "RU";
        if (n.indexOf("english") >= 0) return "EN";
        return n.replace(/[^a-z]/g, "").slice(0, 2).toUpperCase();
    }

    function next() { Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]); }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") root.name = event.data.slice(event.data.indexOf(",") + 1);
        }
    }
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const k = JSON.parse(text).keyboards;
                    const main = k.find(x => x.main) || k[0];
                    if (main && root.name === "") root.name = main.active_keymap;
                } catch (e) {}
            }
        }
    }
}
