pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs

// Which panel is open, and on which monitor. Only the focused monitor ever opens one.
Singleton {
    id: root

    property string panel: ""        // "" | control | launcher | switcher
    property string panelScreen: ""

    // wallpaper shown while the switcher previews (focused monitor only), "" = the real one
    property string previewWallpaper: ""
    // wallpaper just confirmed: shown on every monitor until torii-theme has written the new tokens
    property string pendingWallpaper: ""

    Connections {
        target: Theme
        function onWallpaperChanged() {
            if (Theme.wallpaper === root.pendingWallpaper) root.pendingWallpaper = "";
        }
    }
    Timer {
        interval: 6000
        running: root.pendingWallpaper !== ""
        onTriggered: root.pendingWallpaper = ""
    }

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
