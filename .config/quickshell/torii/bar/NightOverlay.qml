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

    // 6500 K = no tint; lower = a deeper, darker red-orange layer (it dims a little, like a real night mode)
    readonly property real warmth: Math.max(0, Math.min(1, (6500 - kelvin) / 4500))
    readonly property real strength: warmth <= 0 ? 0 : 0.10 + 0.32 * warmth
    readonly property color warm: Qt.rgba(0.50, 0.16 * (1 - warmth) + 0.03, 0.0, 1)

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
