import qs
import QtQuick
import qs.widgets
import qs.services

// Volume read-out that slides open inside the notch for a moment after the volume changes.
Item {
    id: root

    readonly property bool shown: Osd.shown
    readonly property real level: Audio.muted ? 0 : Audio.volume
    readonly property string glyph: (Audio.muted || Audio.volume <= 0) ? Icons.volumeMute
        : Audio.volume < 0.34 ? Icons.volumeLow : (Audio.volume < 0.67 ? Icons.volumeMedium : Icons.volumeHigh)

    height: 20
    width: shown ? 22 + 8 + 64 + 8 + pct.implicitWidth : 0
    opacity: shown ? 1 : 0
    visible: width > 0.5
    clip: true

    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Glyph {
        x: 0
        width: 22
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyph
        size: 14
        color: Audio.muted ? Theme.muted : Theme.accent
    }
    Rectangle {
        x: 30
        width: 64
        height: 4
        radius: 2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.surface2
        Rectangle {
            width: parent.width * root.level
            height: parent.height
            radius: 2
            color: Audio.muted ? Theme.muted : Theme.accent
            Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        }
    }
    // the number counts along with the bar (headphones with their own volume control report a few big steps, not every notch)
    property real shownPct: Math.round(Audio.volume * 100)
    Behavior on shownPct { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
    Label {
        id: pct
        x: 102
        anchors.verticalCenter: parent.verticalCenter
        text: Audio.muted ? "mute" : Math.round(root.shownPct) + "%"
        color: Theme.fgDim
    }
}
