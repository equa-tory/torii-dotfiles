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
    readonly property var notifications: adapter.notifications
    readonly property var sounds: adapter.sounds
    readonly property var activities: adapter.activities
    readonly property var media: adapter.media
    readonly property var widgets: adapter.widgets
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
                property string location: ""     // city name; empty = the one in the system timezone
                property real lat: 0               // set both to pin exact coordinates (0 = automatic)
                property real lon: 0
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
            property JsonObject notifications: JsonObject {
                property real popupSeconds: 5          // how long a notification stays in the notch
                property string expand: "side"          // side: its own pill next to the notch | center: the notch grows around it
                property bool badgeInDnd: false        // show the unread count while do not disturb is on
            }
            property JsonObject sounds: JsonObject {
                // a file name inside ~/.config/torii/sounds/ or an absolute path; empty = reminder.* / notification.* from that folder
                property string reminder: ""
                property string notification: ""
                property real volume: 0.8
            }
            property JsonObject activities: JsonObject {
                property string side: "right"          // right | left of the notch
                property string style: "pill"          // pill (one round pill) | circles (one circle each)
            }
            property JsonObject media: JsonObject {
                property int seekSeconds: 10           // Left/Right while the media activity is open
            }
            property JsonObject widgets: JsonObject {
                // shown only while the launcher or the control panel is open: system, claude, battery
                property var left: ["system"]
                property var right: ["claude", "battery"]
            }
            property string quicklinks: "~/.config/torii/quicklinks.json"
        }
    }
}
