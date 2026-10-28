import qs
import qs.services
import qs.widgets
import Quickshell
import QtQuick
import QtQuick.Layouts

// A vertical volume slider per program that plays sound. Tap the icon: normal > silent always > silent while not focused > normal.
Section {
    id: root

    title: "Apps"
    visible: AppAudio.streams.length > 0

    readonly property var streams: AppAudio.streams
    function iconOf(n) {
        const i = n.properties["application.icon-name"] || n.properties["application.process.binary"] || "";
        return i === "" ? "" : Quickshell.iconPath(i, true);
    }
    readonly property var modeText: ({ "": "", mute: "silent", focus: "silent when not focused" })

    // keyboard (the control panel forwards the keys): row = the highlighted program. Left/Right move between programs (and out of the
    // section at the ends), Up/Down change its volume, Enter changes the mode.
    property int row: -1
    readonly property bool canNav: visible
    function take(last) { row = last ? streams.length - 1 : 0; }
    function release() { row = -1; }
    function nav(k) {
        const n = row >= 0 && row < streams.length ? streams[row] : null;
        if (k === "left") { if (row > 0) { row--; return true; } return false; }
        if (k === "right") { if (row < streams.length - 1) { row++; return true; } return false; }
        if ((k === "up" || k === "down") && n && n.audio) {
            n.audio.volume = Math.max(0, Math.min(1, n.audio.volume + (k === "up" ? 0.05 : -0.05)));
            return true;
        }
        if (k === "enter" && n) { AppAudio.setMode(n, AppAudio.nextMode(AppAudio.modeOf(n))); return true; }
        return k === "up" || k === "down";
    }

    Flow {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        spacing: 6

        Repeater {
            model: root.streams
            delegate: Rectangle {
                id: col
                required property var modelData
                required property int index
                readonly property var audio: modelData.audio
                readonly property string mode: AppAudio.modeOf(modelData)
                readonly property bool silent: audio ? audio.muted : false

                width: 52
                height: 196
                radius: 10
                color: index === root.row ? Theme.surface2 : Theme.surface
                border.width: index === root.row ? 1 : 0
                border.color: Theme.accent

                Label {
                    anchors { top: parent.top; topMargin: 6; horizontalCenter: parent.horizontalCenter }
                    text: col.audio ? Math.round(col.audio.volume * 100) : ""
                    color: col.silent ? Theme.muted : Theme.fgDim
                    font.pixelSize: Config.font.size - 2
                }
                VSlider {
                    anchors { top: parent.top; topMargin: 26; horizontalCenter: parent.horizontalCenter }
                    height: 100
                    value: col.audio ? col.audio.volume : 0
                    dim: col.silent
                    onMoved: v => { if (col.audio) col.audio.volume = v; }
                }
                // the icon is the mute button
                Item {
                    id: btn
                    anchors { top: parent.top; topMargin: 134; horizontalCenter: parent.horizontalCenter }
                    width: 30; height: 30
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: iconArea.containsMouse ? Theme.overlay : "transparent"
                    }
                    Image {
                        id: img
                        anchors.centerIn: parent
                        width: 20; height: 20
                        sourceSize: Qt.size(40, 40)
                        source: root.iconOf(col.modelData)
                        visible: status === Image.Ready
                        opacity: col.silent ? 0.35 : 1
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: img.status !== Image.Ready
                        text: AppAudio.nameOf(col.modelData).charAt(0).toUpperCase()
                        color: col.silent ? Theme.muted : Theme.fgDim
                        font.weight: Font.Medium
                    }
                    Glyph {                       // silent now: a crossed-out speaker over the icon
                        anchors.centerIn: parent
                        visible: col.silent
                        text: Icons.volumeMute
                        size: 14
                        color: Theme.red
                    }
                    Glyph {                       // "silent when not focused": a small marker in the corner
                        visible: col.mode === "focus"
                        x: parent.width - width; y: parent.height - height
                        text: Icons.g(0xF06D0)
                        size: 11
                        color: Theme.accent
                    }
                    MouseArea {
                        id: iconArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppAudio.setMode(col.modelData, AppAudio.nextMode(col.mode))
                    }
                }
                Label {
                    anchors { top: parent.top; topMargin: 168; left: parent.left; right: parent.right; leftMargin: 3; rightMargin: 3 }
                    horizontalAlignment: Text.AlignHCenter
                    text: AppAudio.nameOf(col.modelData)
                    color: col.silent ? Theme.muted : Theme.fg
                    font.pixelSize: Config.font.size - 3
                    elide: Text.ElideRight
                }
            }
        }
    }

    Label {
        readonly property var cur: root.row >= 0 && root.row < root.streams.length ? root.streams[root.row] : null
        visible: true
        Layout.leftMargin: 10
        color: Theme.subtle
        font.pixelSize: Config.font.size - 2
        text: cur ? AppAudio.nameOf(cur) + (root.modeText[AppAudio.modeOf(cur)] ? "  ·  " + root.modeText[AppAudio.modeOf(cur)] : "")
                  : "Tap an icon: silent  ›  silent when not focused  ›  normal"
    }
}
