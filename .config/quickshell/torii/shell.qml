//@ pragma UseQApplication
import Quickshell
import Quickshell.Hyprland
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

    // leaving the workspace (bind, gesture) also dismisses an open panel
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (Panels.panel !== "" && (event.name === "workspacev2" || event.name === "focusedmonv2"))
                Panels.close();
        }
    }

    // the window history for Alt+Tab has to run from the start
    Component.onCompleted: Windows.touch("")

    Ipc {}
}
