//@ pragma UseQApplication
import Quickshell
import QtQuick
import qs.bar

ShellRoot {
    // Notch + wallpaper on every monitor (hotplug safe: Quickshell.screens updates live)
    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: perScreen
            required property var modelData

            Wallpaper { screen: perScreen.modelData }
            Notch { screen: perScreen.modelData }
        }
    }

    Ipc {}
}
