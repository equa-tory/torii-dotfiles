import qs
import qs.panels
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
    readonly property bool panelHere: Panels.panel !== "" && Panels.panelScreen === screen.name

    readonly property real contentW: row.implicitWidth + 36
    readonly property real panelW: panelHere && panelLoader.item ? panelLoader.item.implicitWidth : 0
    readonly property real panelH: panelHere && panelLoader.item ? panelLoader.item.implicitHeight : 0
    readonly property real bodyW: Math.max(contentW, panelW)
    readonly property real bodyH: barH + panelH

    WlrLayershell.namespace: "torii-notch"
    WlrLayershell.keyboardFocus: panelHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; left: true; right: true }
    // full height: while a panel is open the whole window takes input so a click outside the panel closes it
    // (Hyprland routes pointer input only to the exclusive-keyboard layer, so a separate scrim never sees it)
    implicitHeight: screen.height
    exclusiveZone: Math.max(0, topGap + barH - Config.notch.zoneTrim)
    color: "transparent"
    mask: Region { item: win.panelHere ? catcher : shape }

    // Esc closes the panel. (QML `Shortcut` segfaults in Qt 6.12 when the shell hot-reloads, so use a key handler.)
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Panels.close()
    }
    onPanelHereChanged: if (panelHere) keys.forceActiveFocus()

    Item {
        id: catcher
        anchors.fill: parent
        MouseArea {
            anchors.fill: parent
            enabled: win.panelHere
            acceptedButtons: Qt.AllButtons
            onPressed: Panels.close()
        }
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

        // clicks on the black body itself never fall through to the catcher
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Row {
            id: row
            x: win.ear + (win.bodyW - width) / 2
            height: win.barH
            spacing: 16

            Workspaces { screen: win.screen; anchors.verticalCenter: parent.verticalCenter }
            Clock { anchors.verticalCenter: parent.verticalCenter }
            Weather { anchors.verticalCenter: parent.verticalCenter }
            ControlButton { anchors.verticalCenter: parent.verticalCenter; open: win.panelHere && Panels.panel === "control" }
        }

        Loader {
            id: panelLoader
            x: win.ear
            y: win.barH
            width: win.bodyW
            height: win.panelH
            active: win.panelHere
            clip: true
            sourceComponent: Panels.panel === "control" ? controlPanel
                           : Panels.panel === "switcher" ? switcherPanel
                           : Panels.panel === "launcher" ? launcherPanel : null
        }
    }

    Component { id: controlPanel; ControlPanel {} }
    Component { id: switcherPanel; Switcher { maxWidth: win.width - 160 } }
    Component { id: launcherPanel; Launcher {} }
}
