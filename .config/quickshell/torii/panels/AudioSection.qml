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

    // keyboard (the control panel forwards the keys): row 0 volume, 1 output, 2 input; idx = the highlighted entry of an open list (-1 = the row itself)
    property int row: -1
    property int idx: -1
    readonly property var openList: outOpen ? Audio.sinks : (inOpen ? Audio.sources : null)
    readonly property bool canNav: visible
    function take(last) { row = last ? 2 : 0; idx = -1; }
    function release() { row = -1; idx = -1; outOpen = false; inOpen = false; }
    function nav(k) {
        if (k === "up") {
            if (openList) { if (idx >= 0) idx--; return true; }
            if (row > 0) { row--; return true; }
            return false;
        }
        if (k === "down") {
            if (openList) { idx = Math.min(openList.length - 1, idx + 1); return true; }
            if (row < 2) { row++; return true; }
            return false;
        }
        if (k === "left" || k === "right") {
            if (row === 0) Audio.setVolume(Audio.volume + (k === "left" ? -0.05 : 0.05));
            return true;
        }
        if (k === "enter") {
            if (row === 0) Audio.toggleMute();
            else if (openList) {
                if (idx >= 0) (row === 1 ? Audio.setSink : Audio.setSource)(openList[idx].key);
                outOpen = false; inOpen = false; idx = -1;
            } else {
                if (row === 1) outOpen = true; else inOpen = true;
                idx = Math.max(0, (row === 1 ? Audio.sinks : Audio.sources).findIndex(d => d.current));
            }
            return true;
        }
        if (k === "m") { Audio.toggleSourceMute(); return true; }                              // M: mute the microphone
        if (k === "l") { Audio.toggleMonitor(); return true; }                                 // L: listen to the microphone
        if (k === "p") { Audio.pinned !== "" ? Audio.unpin() : Audio.pinCurrent(); return true; } // P: pin the output
        return false;
    }

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
            active: root.row === 0
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
            color: root.row === 0 ? Theme.accent : (Audio.muted ? Theme.muted : Theme.fgDim)
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 38
        }
    }

    // output
    ListRow {
        Layout.fillWidth: true
        glyph: Icons.speaker
        title: Audio.sinkLabel
        current: root.row === 1 && root.idx < 0
        subtitle: Audio.pinned === "" ? "Output" : "Output  ·  kept on " + Config.audio.pinnedLabel + (Audio.pinnedHere ? "" : " (not connected)")
        onClicked: { root.outOpen = !root.outOpen; root.inOpen = false; }
        IconButton {
            glyph: Audio.pinned !== "" ? Icons.pin : Icons.pinOff
            size: 14
            accent: Audio.pinned !== ""
            onClicked: Audio.pinned !== "" ? Audio.unpin() : Audio.pinCurrent()
        }
        Glyph { text: root.outOpen ? Icons.chevronUp : Icons.chevronDown; size: 14 }
    }
    Repeater {
        model: root.outOpen ? Audio.sinks : []
        delegate: ListRow {
            required property var modelData
            required property int index
            current: index === root.idx
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
        current: root.row === 2 && root.idx < 0
        onClicked: { root.inOpen = !root.inOpen; root.outOpen = false; }
        IconButton {
            glyph: Icons.headphones
            size: 14
            accent: Audio.monitoring
            onClicked: Audio.toggleMonitor()
        }
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
            required property int index
            current: index === root.idx
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
