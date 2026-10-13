pragma Singleton
import Quickshell

// Nerd Font (Material Design) glyphs used by the panels.
Singleton {
    function g(cp) { return String.fromCodePoint(cp); }

    readonly property string volumeHigh: g(0xF057E)
    readonly property string volumeMedium: g(0xF0580)
    readonly property string volumeLow: g(0xF057F)
    readonly property string volumeMute: g(0xF075F)
    readonly property string volumeOff: g(0xF0581)
    readonly property string mic: g(0xF036C)
    readonly property string micOff: g(0xF036D)
    readonly property string bluetooth: g(0xF00AF)
    readonly property string bluetoothAudio: g(0xF00B0)
    readonly property string bluetoothConnect: g(0xF00B1)
    readonly property string bluetoothOff: g(0xF00B2)
    readonly property string wifi: g(0xF05A9)
    readonly property string wifiOff: g(0xF05AA)
    readonly property var wifiStrength: [g(0xF091F), g(0xF0922), g(0xF0925), g(0xF0928)]
    readonly property string lock: g(0xF033E)
    readonly property string ethernet: g(0xF0200)
    readonly property string refresh: g(0xF0450)
    readonly property string close: g(0xF0156)
    readonly property string check: g(0xF012C)
    readonly property string chevronDown: g(0xF0140)
    readonly property string chevronUp: g(0xF0143)
    readonly property string headphones: g(0xF02CB)
    readonly property string speaker: g(0xF04C3)
    readonly property string keyboard: g(0xF030C)
    readonly property string mouse: g(0xF037D)
    readonly property string phone: g(0xF011C)
    readonly property string laptop: g(0xF0322)
    readonly property string battery: g(0xF0079)
    readonly property string trash: g(0xF01B4)
    readonly property string link: g(0xF0337)
    readonly property string search: g(0xF0349)
}
