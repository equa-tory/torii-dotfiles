import qs
import QtQuick
import Quickshell
import qs.widgets
import qs.services

// The newest notification: icon, title and one line of text, as wide as the text needs (at most `full`).
// notifications.expand "center": it opens inside the notch, which grows around it. "side": it is its own pill next to
// the notch (`pill`), and the notch stays where it is.
// Click runs its default action (or brings the app forward), right click dismisses, hovering keeps it.
Item {
    id: root

    readonly property var n: Notifs.current
    readonly property bool shown: n !== null
    property var last: null                      // keeps the text while the pop-up closes
    onNChanged: if (n) last = n

    property bool pill: false                    // its own round background (side mode)
    readonly property real pad: pill ? 12 : 0
    readonly property real full: 340
    readonly property real textW: Math.max(title.implicitWidth, line.implicitWidth)
    readonly property real wanted: Math.min(full, 30 + textW + 6) + 2 * pad
    height: pill ? 34 : 26
    width: shown ? Math.max(110, wanted) : 0
    opacity: shown ? 1 : 0
    visible: width > 0.5
    clip: true

    Rectangle { anchors.fill: parent; visible: root.pill; radius: height / 2; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Config.notch.opacity) }

    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    readonly property string icon: last ? last.icon : ""

    Item {
        id: iconBox
        x: root.pad
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
        x: 30 + root.pad
        width: root.width - 30 - 2 * root.pad - 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: -1
        Label {
            id: title
            width: parent.width
            text: root.last ? root.last.summary || root.last.app : ""
            elide: Text.ElideRight
            font.pixelSize: Config.font.size - 1
            font.weight: Font.Medium
        }
        Label {
            id: line
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
