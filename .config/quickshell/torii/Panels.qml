pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import qs.services

// Which panel is open, and on which monitor. Only the focused monitor ever opens one.
Singleton {
    id: root

    property string panel: ""        // "" | control | launcher | switcher | weather | calendar
    property string panelScreen: ""
    property var launcherPath: []    // menu ids the launcher opens inside of next time (e.g. ["notifications"])

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

    // the widgets around the notch only run while the launcher or the control panel is open
    readonly property bool widgetsOn: panel === "launcher" || panel === "control"
    Binding { target: ClaudeUsage; property: "watching"; value: root.widgetsOn }
    Binding { target: Sys; property: "watching"; value: root.widgetsOn }

    function open(name) {
        panelScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        panel = name;
    }

    function openLauncherAt(ids) { launcherPath = ids; open("launcher"); }

    function close() {
        panel = "";
        previewWallpaper = "";
    }

    function toggle(name) {
        if (panel === name) close(); else open(name);
    }
}
