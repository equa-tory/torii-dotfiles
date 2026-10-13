import qs
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// One notch per monitor. The window is a tall transparent strip; only the black body takes input.
// Panels grow out of the body (same black, same corners).
PanelWindow {
    id: win

    readonly property bool floating: Config.notch.shape === "floating"
    readonly property real barH: Config.notch.height
    readonly property real topGap: floating ? Config.notch.gap : 0
    readonly property real ear: floating ? 0 : Config.notch.radius
    readonly property bool panelHere: State.panel !== "" && State.panelScreen === screen.name

    readonly property real contentW: row.implicitWidth + 36
    readonly property real bodyW: Math.max(contentW, panelHere ? panelHost.implicitWidth : 0)
    readonly property real bodyH: barH + (panelHere ? panelHost.implicitHeight : 0)

    WlrLayershell.namespace: "torii-notch"
    WlrLayershell.keyboardFocus: panelHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; left: true; right: true }
    implicitHeight: 620
    exclusiveZone: topGap + barH
    color: "transparent"
    mask: Region { item: shape }

    HyprlandFocusGrab {
        windows: [win]
        active: win.panelHere
        onCleared: State.close()
    }

    Shortcut {
        sequence: "Escape"
        enabled: win.panelHere
        onActivated: State.close()
    }

    NotchShape {
        id: shape
        x: Math.round((win.width - width) / 2)
        y: win.topGap
        width: win.bodyW + 2 * win.ear
        height: win.bodyH
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Config.notch.opacity)
        radius: Config.notch.radius
        floating: win.floating

        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }

        Row {
            id: row
            x: win.ear + (win.bodyW - width) / 2
            height: win.barH
            spacing: 16

            Workspaces { screen: win.screen; anchors.verticalCenter: parent.verticalCenter }
            Clock { anchors.verticalCenter: parent.verticalCenter }
            Weather { anchors.verticalCenter: parent.verticalCenter }
            ControlButton { anchors.verticalCenter: parent.verticalCenter; open: win.panelHere && State.panel === "control" }
        }

        Item {
            id: panelHost
            x: win.ear
            y: win.barH
            width: win.bodyW
            implicitWidth: 0
            implicitHeight: 0
            clip: true
        }
    }
}
