import qs
import QtQuick
import Quickshell
import qs.widgets
import qs.services

// The newest notification, slid open at the right end of the notch: icon, title and one line of text.
// Click runs its default action (or brings the app forward), right click dismisses, hovering keeps it.
Item {
    id: root

    readonly property var n: Notifs.current
    readonly property bool shown: n !== null
    property var last: null                      // keeps the text while the pop-up closes
    onNChanged: if (n) last = n

    readonly property real full: 340
    height: 26
    width: shown ? full : 0
    opacity: shown ? 1 : 0
    visible: width > 0.5
    clip: true

    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    readonly property string icon: last ? last.icon : ""

    Item {
        id: iconBox
        width: 22; height: 22
        anchors.verticalCenter: parent.verticalCenter
        Image {
            id: img
            anchors.fill: parent
            sourceSize: Qt.size(44, 44)
            asynchronous: true
            smooth: true
            source: {
                const i = root.icon;
                if (!i) return "";
                if (i.indexOf("image:") === 0 || i.indexOf("file:") === 0) return i;
                return i.charAt(0) === "/" ? "file://" + i : Quickshell.iconPath(i, true);
            }
        }
        Glyph {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            text: root.last && root.last.urgent ? Icons.bellRing : Icons.bell
            size: 14
            color: root.last && root.last.urgent ? Theme.red : Theme.accent
        }
    }

    Column {
        x: 30
        width: root.full - 30 - 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: -1
        Label {
            width: parent.width
            text: root.last ? root.last.summary || root.last.app : ""
            elide: Text.ElideRight
            font.pixelSize: Config.font.size - 1
            font.weight: Font.Medium
        }
        Label {
            width: parent.width
            visible: text !== ""
            text: root.last ? root.last.body.split("\n")[0] : ""
            color: Theme.fgDim
            elide: Text.ElideRight
            font.pixelSize: Config.font.size - 3
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: Notifs.hovered = true
        onExited: Notifs.hovered = false
        onClicked: mouse => {
            const e = Notifs.current;
            if (!e) return;
            if (mouse.button === Qt.LeftButton) Notifs.activate(e);
            Notifs.dismiss(e.uid);
        }
    }
}
