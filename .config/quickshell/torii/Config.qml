pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// One hand-edited file: ~/.config/torii/config.json. Every key is optional; the defaults below apply.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: home + "/.local/state/torii"

    readonly property var notch: adapter.notch
    readonly property var workspaces: adapter.workspaces
    readonly property var weather: adapter.weather
    readonly property var wallpaper: adapter.wallpaper
    readonly property var apps: adapter.apps
    readonly property var theme: adapter.theme
    readonly property var font: adapter.font
    readonly property var launcher: adapter.launcher
    readonly property string quicklinks: adapter.quicklinks

    function expand(path) {
        return path.startsWith("~") ? home + path.slice(1) : path;
    }

    FileView {
        path: root.home + "/.config/torii/config.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        adapter: JsonAdapter {
            id: adapter

            property JsonObject notch: JsonObject {
                property string shape: "attached"   // attached | floating
                property real opacity: 1.0
                property int radius: 16
                property int height: 34
                property int gap: 6
                property int zoneTrim: 12           // px taken off the reserved strip: smaller gap between the notch and windows
            }
            property JsonObject workspaces: JsonObject {
                property int count: 5
            }
            property JsonObject weather: JsonObject {
                property real lat: 55.75
                property real lon: 37.62
                property int refreshMin: 20
            }
            property JsonObject wallpaper: JsonObject {
                property string dir: "~/Pictures/wallpapers"
                property int transitionMs: 600
            }
            property JsonObject apps: JsonObject {
                property string dir: "~/apps"
            }
            property JsonObject theme: JsonObject {
                property real tint: 0.15
            }
            property JsonObject font: JsonObject {
                property string family: "JetBrainsMono Nerd Font"
                property int size: 13
            }
            property JsonObject launcher: JsonObject {
                property bool rememberBack: true       // going back lands on the row you came from
                property bool rememberForward: true    // entering a menu again lands on the row you left there
                property bool menuHistory: true        // menus you used before rank higher while you search
                property string placeholder: "Search apps  ·  ↓ opens the menus"
            }
            property string quicklinks: "~/.config/torii/quicklinks.json"
        }
    }
}
