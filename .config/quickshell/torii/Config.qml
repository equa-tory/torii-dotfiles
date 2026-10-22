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
    readonly property var capture: adapter.capture
    readonly property var install: adapter.install
    readonly property var workspaces: adapter.workspaces
    readonly property var weather: adapter.weather
    readonly property var wallpaper: adapter.wallpaper
    readonly property var apps: adapter.apps
    readonly property var theme: adapter.theme
    readonly property var font: adapter.font
    readonly property var launcher: adapter.launcher
    readonly property var limine: adapter.limine
    readonly property var notifications: adapter.notifications
    readonly property var sounds: adapter.sounds
    readonly property var activities: adapter.activities
    readonly property var media: adapter.media
    readonly property var widgets: adapter.widgets
    readonly property var features: adapter.features
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
                property bool clockDate: false      // the clock shows the date next to the time
                property int radius: 16
                property int height: 34
                property int gap: 6
                property int zoneTrim: 12           // px taken off the reserved strip: smaller gap between the notch and windows
            }
            property JsonObject capture: JsonObject {
                property bool freeze: true          // freeze the screen while you drag a zone (screenshot zone, text, QR)
                property JsonObject rec: JsonObject {   // screen recording (torii-record)
                    property bool system: true          // what the computer plays
                    property bool mic: true             // the microphone
                    property var apps: []               // programs recorded on a track of their own
                    property bool lanes: true           // every source its own audio track; false: mixed into one
                    property bool folder: false         // a folder with the video and one audio file per source
                    property real micGain: 1.0          // louder or quieter microphone in the recording only
                }
            }
            property JsonObject install: JsonObject {
                property bool track: true           // packages installed from the launcher are added to packages/*.txt (and removed from them)
            }
            property JsonObject workspaces: JsonObject {
                property int count: 5
            }
            property JsonObject weather: JsonObject {
                property string location: ""     // city name; empty = the one in the system timezone
                property real lat: 0               // set both to pin exact coordinates (0 = automatic)
                property real lon: 0
                property int refreshMin: 20
                property string proxy: ""       // e.g. http://127.0.0.1:10808: tried when the direct request fails (the weather service is blocked in some countries)
            }
            property JsonObject wallpaper: JsonObject {
                property string dir: "~/Pictures/wallpapers"
                property int transitionMs: 600
                property string shuffle: "off"      // random wallpaper: off | 5 | 60 (minutes) | login
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
                // menus whose rows are left out of the search (the menu itself still shows up): path of ids, e.g. "setup/rules"
                property var searchHidden: ["setup/rules"]
                // per item or folder (Ctrl+K in the launcher), by path of ids: { "apps/firefox": { name, where, alias, bind, pin, hide } }
                property var custom: ({})
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
                property string style: "circles"       // circles (one circle each) | pill (one round pill)
            }
            property JsonObject media: JsonObject {
                property bool onlyWhenUnfocused: true  // hide the media activity while the player's own window has focus
                property int seekSeconds: 10           // Left/Right while the media activity is open
            }
            property JsonObject widgets: JsonObject {
                // shown only while the launcher or the control panel is open: system, claude, battery
                property var left: ["claude"]
                property var right: ["battery"]
            }
            property JsonObject features: JsonObject {
                property bool systemInfo: false        // CPU/RAM/GPU widget and the Processes menu: switched off for now, the code is kept
            }
            property JsonObject limine: JsonObject {
                property string image: ""              // boot menu picture; empty = the desktop wallpaper
                property real brightness: 0            // -100..100 %
                property real blur: 1.5                // pixels
                property real panel: 0.3               // 0..1: how solid the dark panel behind the menu text is
            }
            property string quicklinks: "~/.config/torii/quicklinks.json"
        }
    }
}
