import qs
import qs.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

// Volume, Bluetooth, Network, background apps. Grows out of the notch.
Item {
    id: root

    implicitWidth: 380
    implicitHeight: Math.min(660, col.implicitHeight + 28)

    opacity: 0
    focus: true
    Component.onCompleted: { opacity = 1; forceActiveFocus(); }
    // Keyboard: arrows move through Sound, Bluetooth and the background apps (Enter acts on the highlighted thing, Left/Right
    // change the volume, M mutes the mic, L listens to it, P pins the output); Esc steps back, then closes the panel.
    property int stop: -1
    readonly property var stops: [audioSec, btSec, traySec].filter(s => s.canNav)
    function press(k) {
        if (stops.length === 0) return;
        if (stop < 0 || stop >= stops.length) {
            if (k === "up" || k === "down" || k === "left" || k === "right" || k === "enter") { stop = 0; stops[0].take(false); }
            return;
        }
        const s = stops[stop];
        if (s.nav(k) || (k !== "up" && k !== "down")) return;
        const n = stop + (k === "down" ? 1 : -1);
        s.release();
        if (n < 0) stop = -1;
        else if (n < stops.length) { stop = n; stops[n].take(k === "up"); }
        else s.take(true);
    }
    function back() {
        if (stop < 0 || stop >= stops.length) { Panels.close(); return; }
        const s = stops[stop];
        if (s.openList) { s.outOpen = false; s.inOpen = false; s.idx = -1; return; }
        s.release(); stop = -1;
    }
    Keys.onLeftPressed: press("left")
    Keys.onRightPressed: press("right")
    Keys.onUpPressed: press("up")
    Keys.onDownPressed: press("down")
    Keys.onReturnPressed: press("enter")
    Keys.onEnterPressed: press("enter")
    Keys.onEscapePressed: back()
    Keys.onPressed: event => {
        const k = { [Qt.Key_M]: "m", [Qt.Key_L]: "l", [Qt.Key_P]: "p" }[event.key];
        if (k && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) { press(k); event.accepted = true; }
    }
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 28
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            x: 16
            y: 4
            width: parent.width - 32
            spacing: 16

            // notifications: opens the launcher inside its Notifications menu; the badge is the unread count
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Item {
                    implicitWidth: 28
                    implicitHeight: 28
                    IconButton {
                        anchors.fill: parent
                        glyph: Notifs.dnd ? Icons.bellOff : Icons.bell
                        active: Notifs.badgeVisible
                        onClicked: Panels.openLauncherAt(["notifications"])
                    }
                    Rectangle {
                        visible: Notifs.badgeVisible
                        x: parent.width - width + 3
                        y: -3
                        width: Math.max(16, badgeText.implicitWidth + 8)
                        height: 16
                        radius: 8
                        color: Theme.accent
                        Label { id: badgeText; anchors.centerIn: parent; text: Notifs.unread > 99 ? "99+" : Notifs.unread; color: Theme.accentFg; font.pixelSize: 10 }
                    }
                }
            }

            AudioSection { id: audioSec; Layout.fillWidth: true }
            BluetoothSection { id: btSec; Layout.fillWidth: true }
            NetworkSection { Layout.fillWidth: true }
            TraySection { id: traySec; Layout.fillWidth: true }
        }
    }
}
