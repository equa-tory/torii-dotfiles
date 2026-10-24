pragma Singleton
import qs
import Quickshell
import QtQuick

// Brief on-notch read-out of the output volume. Shown for `holdMs` after it changes (or it is muted).
Singleton {
    id: root

    property bool shown: false
    readonly property int holdMs: 1500
    property bool armed: false            // ignore the values PipeWire reports while it is still starting up

    function pulse() {
        if (!armed) return;
        shown = true;
        hide.restart();
    }

    Timer { id: hide; interval: root.holdMs; onTriggered: root.shown = false }
    Timer { running: true; interval: 2500; onTriggered: root.armed = true }

    Connections {
        target: Audio
        function onVolumeChanged() { root.pulse(); }
        function onMutedChanged() { root.pulse(); }
        function onSinkNodeChanged() { root.armed = false; arm.restart(); }
    }
    Timer { id: arm; interval: 1500; onTriggered: root.armed = true }
}
