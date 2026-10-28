import qs
import qs.services
import qs.widgets
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// Volume of each program that plays sound; tap the icon to mute it.
Section {
    id: root

    title: "Apps"
    visible: streams.length > 0

    readonly property var streams: (Pipewire.nodes.values || []).filter(n => n.isStream && n.type === PwNodeType.AudioOutStream
        && !((n.properties["media.name"] || "").startsWith("torii-")))
    PwObjectTracker { objects: root.streams }

    function nameOf(n) { return n.properties["application.name"] || n.properties["node.name"] || n.name || "?"; }
    function iconOf(n) {
        const i = n.properties["application.icon-name"] || n.properties["application.process.binary"] || "";
        return i === "" ? "" : Quickshell.iconPath(i, true);
    }

    // keyboard (the control panel forwards the keys): row = the highlighted program
    property int row: -1
    readonly property bool canNav: visible
    function take(last) { row = last ? streams.length - 1 : 0; }
    function release() { row = -1; }
    function nav(k) {
        const n = row >= 0 && row < streams.length ? streams[row] : null;
        if (k === "up") { if (row > 0) { row--; return true; } return false; }
        if (k === "down") { if (row < streams.length - 1) { row++; return true; } return false; }
        if ((k === "left" || k === "right") && n && n.audio) {
            n.audio.volume = Math.max(0, Math.min(1, n.audio.volume + (k === "left" ? -0.05 : 0.05)));
            return true;
        }
        if (k === "enter" && n && n.audio) { n.audio.muted = !n.audio.muted; return true; }
        return k === "left" || k === "right";
    }

    Repeater {
        model: root.streams
        delegate: RowLayout {
            id: line
            required property var modelData
            required property int index
            readonly property var audio: modelData.audio

            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 8
            spacing: 8

            Rectangle {
                implicitWidth: 28; implicitHeight: 28; radius: 8
                color: iconArea.containsMouse || index === root.row ? Theme.surface2 : Theme.surface
                border.width: index === root.row ? 1 : 0
                border.color: Theme.accent
                Image {
                    id: img
                    anchors.centerIn: parent
                    width: 18; height: 18
                    sourceSize: Qt.size(36, 36)
                    source: root.iconOf(line.modelData)
                    visible: status === Image.Ready
                    opacity: line.audio && line.audio.muted ? 0.35 : 1
                }
                Label {
                    anchors.centerIn: parent
                    visible: img.status !== Image.Ready
                    text: root.nameOf(line.modelData).charAt(0).toUpperCase()
                    color: line.audio && line.audio.muted ? Theme.muted : Theme.fgDim
                    font.weight: Font.Medium
                }
                Glyph {                       // muted: a crossed-out speaker over the icon
                    anchors.centerIn: parent
                    visible: line.audio && line.audio.muted
                    text: Icons.volumeMute
                    size: 14
                    color: Theme.red
                }
                MouseArea {
                    id: iconArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (line.audio) line.audio.muted = !line.audio.muted
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    text: root.nameOf(line.modelData)
                    color: line.audio && line.audio.muted ? Theme.muted : Theme.fg
                    font.pixelSize: Config.font.size - 1
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Slider {
                    Layout.fillWidth: true
                    value: line.audio ? line.audio.volume : 0
                    dim: line.audio ? line.audio.muted : true
                    onMoved: v => { if (line.audio) line.audio.volume = v; }
                }
            }
            Label {
                text: line.audio ? Math.round(line.audio.volume * 100) + "%" : ""
                color: line.audio && line.audio.muted ? Theme.muted : Theme.fgDim
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 38
            }
        }
    }
}
