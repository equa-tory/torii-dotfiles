import qs
import qs.services
import Quickshell
import Quickshell.Wayland
import QtQuick

// Night light as a warm transparent layer over the screen (Night light > Method > Screen overlay).
// It lets every click through and is drawn above everything, so it does not depend on GPU colour support.
PanelWindow {
    id: win

    readonly property bool active: Live.nightOn && Live.night.mode === "overlay"
    readonly property real kelvin: Live.night.temp

    // 6500 K = no tint, lower = warmer and a little stronger
    readonly property real strength: Math.max(0, Math.min(0.3, (6500 - kelvin) / 4500 * 0.28))
    readonly property color warm: {
        const t = kelvin / 100;
        const r = 1.0;
        const g = Math.max(0, Math.min(1, (99.4708025861 * Math.log(t) - 161.1195681661) / 255));
        const b = t >= 66 ? 1.0 : (t <= 19 ? 0 : Math.max(0, Math.min(1, (138.5177312231 * Math.log(t - 10) - 305.0447927307) / 255)));
        return Qt.rgba(r, g * 0.85, b * 0.6, 1);
    }

    visible: active || fade.running
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "torii-nightlight"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region {}                   // empty: no part of the window takes input

    Rectangle {
        anchors.fill: parent
        color: win.warm
        opacity: win.active ? win.strength : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: 500; easing.type: Easing.InOutQuad } }
    }
}
