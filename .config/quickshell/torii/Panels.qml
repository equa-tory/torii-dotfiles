pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick

// Which panel is open, and on which monitor. Only the focused monitor ever opens one.
Singleton {
    id: root

    property string panel: ""        // "" | control | launcher | switcher
    property string panelScreen: ""

    // wallpaper shown while the switcher previews, "" = the real one
    property string previewWallpaper: ""

    function open(name) {
        panelScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        panel = name;
    }

    function close() {
        panel = "";
        previewWallpaper = "";
    }

    function toggle(name) {
        if (panel === name) close(); else open(name);
    }
}
