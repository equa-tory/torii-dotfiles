pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Colour tokens written by `torii-theme` (~/.local/state/torii/theme/tokens.json). Reloads live.
Singleton {
    id: root

    readonly property color bg: adapter.bg
    readonly property color surface: adapter.surface
    readonly property color surface2: adapter.surface2
    readonly property color overlay: adapter.overlay
    readonly property color border: adapter.border
    readonly property color muted: adapter.muted
    readonly property color subtle: adapter.subtle
    readonly property color fgDim: adapter.fgDim
    readonly property color fg: adapter.fg
    readonly property color accent: adapter.accent
    readonly property color accentDim: adapter.accentDim
    readonly property color accentFg: adapter.accentFg
    readonly property color red: adapter.red
    readonly property color orange: adapter.orange
    readonly property color yellow: adapter.yellow
    readonly property color green: adapter.green
    readonly property color cyan: adapter.cyan
    readonly property color blue: adapter.blue
    readonly property color magenta: adapter.magenta
    readonly property string wallpaper: adapter.wallpaper
    readonly property string mode: adapter.mode

    FileView {
        path: Config.stateDir + "/theme/tokens.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        adapter: JsonAdapter {
            id: adapter
            property string bg: "#000000"
            property string surface: "#161616"
            property string surface2: "#202020"
            property string overlay: "#2a2a2a"
            property string border: "#343434"
            property string muted: "#6a6a6a"
            property string subtle: "#8c8c8c"
            property string fgDim: "#b4b4b4"
            property string fg: "#e8e8e8"
            property string accent: "#7aa2f7"
            property string accentDim: "#4c6aa8"
            property string accentFg: "#101010"
            property string red: "#f7768e"
            property string orange: "#ff9e64"
            property string yellow: "#e0af68"
            property string green: "#9ece6a"
            property string cyan: "#7dcfff"
            property string blue: "#7aa2f7"
            property string magenta: "#bb9af7"
            property string wallpaper: ""
            property string mode: "dark"
        }
    }
}
