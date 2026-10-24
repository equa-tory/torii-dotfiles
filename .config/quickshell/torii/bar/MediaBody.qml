import qs
import QtQuick
import qs.widgets
import qs.services

// The open media activity: what plays (click: bring the player forward), previous / play / next, a seek bar you can
// drag. The wheel and Left/Right seek by media.seekSeconds.
Item {
    id: root

    property var player: Media.player
    readonly property bool playing: player !== null && player.isPlaying
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property real position: player && player.positionSupported ? player.position : 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : -1

    implicitWidth: 430
    implicitHeight: 26

    Column {
        id: text
        width: 170
        anchors.verticalCenter: parent.verticalCenter
        spacing: -1
        Label {
            width: parent.width
            text: (root.player ? root.player.trackTitle || "" : "")
            elide: Text.ElideRight
            font.pixelSize: Config.font.size - 1
            font.weight: Font.Medium
        }
        Label {
            width: parent.width
            text: [root.player ? root.player.trackArtist : "", root.player ? root.player.trackAlbum : ""].filter(x => x).join("  ·  ")
            color: Theme.fgDim
            elide: Text.ElideRight
            font.pixelSize: Config.font.size - 3
        }
    }
    MouseArea {
        x: text.x; y: 0
        width: text.width; height: root.height
        cursorShape: Qt.PointingHandCursor
        onClicked: Media.focus(root.player)
    }

    Row {
        id: buttons
        x: 180
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Repeater {
            model: [
                { g: Icons.skipPrev, act: 0 },
                { g: root.playing ? Icons.pause : Icons.play, act: 1 },
                { g: Icons.skipNext, act: 2 }
            ]
            Item {
                width: 26; height: 24
                Glyph {
                    anchors.centerIn: parent
                    text: modelData.g
                    size: modelData.act === 1 ? 18 : 15
                    color: ma.containsMouse ? Theme.accent : Theme.fg
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (modelData.act === 0) Media.previous(root.player); else if (modelData.act === 1) Media.toggle(root.player); else Media.next(root.player); }
                }
            }
        }
    }

    Item {
        id: seek
        x: 270
        width: root.width - 270
        height: 24
        anchors.verticalCenter: parent.verticalCenter

        Label {
            id: now
            anchors.verticalCenter: parent.verticalCenter
            text: Media.mmss(root.position)
            color: Theme.fgDim
            font.pixelSize: Config.font.size - 3
        }
        Rectangle {
            id: track
            x: now.width + 8
            width: parent.width - now.width - total.width - 16
            height: 4
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.surface2
            Rectangle {
                width: parent.width * Math.max(0, root.progress)
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }
        Label {
            id: total
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: root.length > 0 ? Media.mmss(root.length) : "--:--"
            color: Theme.fgDim
            font.pixelSize: Config.font.size - 3
        }
        MouseArea {
            x: track.x - 4
            width: track.width + 8
            height: parent.height
            enabled: root.player !== null && root.player.canSeek
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: mouse => Media.seekTo((mouse.x - 4) / track.width, root.player)
            onPositionChanged: mouse => { if (pressed) Media.seekTo((mouse.x - 4) / track.width, root.player); }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.NoButton
        onWheel: wheel => Media.seekBy((wheel.angleDelta.y > 0 ? 1 : -1) * Config.media.seekSeconds, root.player)
    }
}
