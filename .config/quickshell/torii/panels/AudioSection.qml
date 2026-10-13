import qs
import qs.services
import qs.widgets
import QtQuick
import QtQuick.Layouts

// Output volume + mute, default output/input pickers, input level.
Section {
    id: root

    property bool outOpen: false
    property bool inOpen: false

    title: "Sound"
    visible: Audio.available

    Component.onCompleted: Audio.watchLevel = true
    Component.onDestruction: Audio.watchLevel = false

    function volumeGlyph() {
        if (Audio.muted || Audio.volume <= 0) return Icons.volumeMute;
        return Audio.volume < 0.34 ? Icons.volumeLow : (Audio.volume < 0.67 ? Icons.volumeMedium : Icons.volumeHigh);
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 8
        spacing: 6

        IconButton {
            glyph: root.volumeGlyph()
            size: 18
            accent: !Audio.muted
            onClicked: Audio.toggleMute()
        }
        Slider {
            Layout.fillWidth: true
            value: Audio.volume
            dim: Audio.muted
            onMoved: v => Audio.setVolume(v)
        }
        Label {
            text: Math.round(Audio.volume * 100) + "%"
            color: Audio.muted ? Theme.muted : Theme.fgDim
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 38
        }
    }

    // output
    ListRow {
        Layout.fillWidth: true
        glyph: Icons.speaker
        title: Audio.sinkLabel
        subtitle: "Output"
        onClicked: { root.outOpen = !root.outOpen; root.inOpen = false; }
        Glyph { text: root.outOpen ? Icons.chevronUp : Icons.chevronDown; size: 14 }
    }
    Repeater {
        model: root.outOpen ? Audio.sinks : []
        delegate: ListRow {
            required property var modelData
            Layout.fillWidth: true
            Layout.leftMargin: 14
            glyph: modelData.current ? Icons.check : ""
            glyphColor: Theme.accent
            title: modelData.label
            titleColor: modelData.current ? Theme.fg : Theme.fgDim
            onClicked: { root.outOpen = false; Audio.setSink(modelData.key); }
        }
    }

    // input + level
    ListRow {
        Layout.fillWidth: true
        glyph: Audio.sourceMuted ? Icons.micOff : Icons.mic
        glyphColor: Audio.sourceMuted ? Theme.muted : Theme.subtle
        title: Audio.sourceLabel
        subtitle: "Input"
        onClicked: { root.inOpen = !root.inOpen; root.outOpen = false; }
        IconButton {
            glyph: Audio.sourceMuted ? Icons.micOff : Icons.mic
            size: 14
            accent: !Audio.sourceMuted
            onClicked: Audio.toggleSourceMute()
        }
        Glyph { text: root.inOpen ? Icons.chevronUp : Icons.chevronDown; size: 14 }
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 40
        Layout.rightMargin: 12
        Layout.preferredHeight: 3
        radius: 1.5
        color: Theme.overlay

        Rectangle {
            width: parent.width * Audio.level
            height: parent.height
            radius: 1.5
            color: Audio.level > 0.85 ? Theme.red : Theme.accent
            Behavior on width { NumberAnimation { duration: 80 } }
        }
    }
    Repeater {
        model: root.inOpen ? Audio.sources : []
        delegate: ListRow {
            required property var modelData
            Layout.fillWidth: true
            Layout.leftMargin: 14
            glyph: modelData.current ? Icons.check : ""
            glyphColor: Theme.accent
            title: modelData.label
            titleColor: modelData.current ? Theme.fg : Theme.fgDim
            onClicked: { root.inOpen = false; Audio.setSource(modelData.key); }
        }
    }
}
