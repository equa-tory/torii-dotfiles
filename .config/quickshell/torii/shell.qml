//@ pragma UseQApplication
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs
import qs.bar
import qs.services

ShellRoot {
    // Notch + wallpaper on every monitor (hotplug safe: Quickshell.screens updates live)
    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: perScreen
            required property var modelData

            Wallpaper { screen: perScreen.modelData }
            Notch { screen: perScreen.modelData }
            NightOverlay { screen: perScreen.modelData }
        }
    }

    // Synchronize only the committed theme, not wallpaper-picker previews.
    Process {
        id: homeAssistantSync
        command: [Config.home + "/.config/torii/bin/torii-homeassistant", "sync"]
    }
    Timer {
        id: homeAssistantDebounce
        interval: 500
        onTriggered: if (!homeAssistantSync.running) homeAssistantSync.running = true
    }
    Connections { target: Theme; function onAccentChanged() { homeAssistantDebounce.restart(); } }
    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: if (!homeAssistantSync.running) homeAssistantSync.running = true
    }

    // leaving the workspace (bind, gesture) also dismisses an open panel
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (Panels.panel !== "" && (event.name === "workspacev2" || event.name === "focusedmonv2"))
                Panels.close();
        }
    }

    // the window history for Alt+Tab has to run from the start
    Component.onCompleted: { Windows.touch(""); AppAudio.touch(); }

    Ipc {}
}
