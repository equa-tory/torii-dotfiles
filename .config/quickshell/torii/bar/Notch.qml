import qs
import qs.panels
import qs.services as Svc
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
    readonly property bool widgetsShown: panelHere && (Panels.panel === "launcher" || Panels.panel === "control")
    readonly property bool notifSide: Config.notifications.expand === "side"
    readonly property bool panelHere: Panels.panel !== "" && Panels.panelScreen === screen.name

    readonly property real contentW: row.implicitWidth + 36
    readonly property real panelW: panelHere && panelLoader.item ? panelLoader.item.implicitWidth : 0
    readonly property real panelH: panelHere && panelLoader.item ? panelLoader.item.implicitHeight : 0
    readonly property real bodyW: Math.max(contentW, panelW)
    readonly property real bodyH: barH + panelH

    WlrLayershell.namespace: "torii-notch"
    // an open media activity can take the keyboard (click it): Left/Right then seek
    readonly property bool mediaOpen: Svc.Live.expanded === "media" && Svc.Media.active
    WlrLayershell.keyboardFocus: panelHere ? WlrKeyboardFocus.Exclusive : (mediaOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
    anchors { top: true; left: true; right: true }
    // full height: while a panel is open the whole window takes input so a click outside the panel closes it
    // (Hyprland routes pointer input only to the exclusive-keyboard layer, so a separate scrim never sees it)
    implicitHeight: screen.height
    exclusiveZone: Math.max(0, topGap + barH - Config.notch.zoneTrim)
    color: "transparent"
    mask: Region { item: win.panelHere ? catcher : shape; regions: [ Region { item: activity }, Region { item: popup } ] }

    // Esc closes the panel. (QML `Shortcut` segfaults in Qt 6.12 when the shell hot-reloads, so use a key handler.)
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: { if (win.panelHere) Panels.close(); else Svc.Live.expanded = ""; }
        Keys.onLeftPressed: if (win.mediaOpen) Svc.Media.seekBy(-Config.media.seekSeconds)
        Keys.onRightPressed: if (win.mediaOpen) Svc.Media.seekBy(Config.media.seekSeconds)
        Keys.onSpacePressed: if (win.mediaOpen) Svc.Media.toggle()
    }
    // the same editing keys for the control panel's text fields (the launcher handles its own)
    Connections {
        target: Panels
        enabled: win.panelHere && Panels.panel !== "launcher"
        function onEditRequested(action) {
            const it = win.activeFocusItem;
            if (!it) return;
            if (action === "copy" && it.copy) it.copy();
            else if (action === "paste" && it.paste) it.paste();
            else if (action === "cut" && it.cut) it.cut();
            else if (action === "undo" && it.undo) it.undo();
            else if (action === "selectall" && it.selectAll) it.selectAll();
            else if (action === "home" && it.cursorPosition !== undefined) it.cursorPosition = 0;
            else if (action === "end" && it.cursorPosition !== undefined && it.text !== undefined) it.cursorPosition = it.text.length;
        }
    }
    onPanelHereChanged: if (panelHere) keys.forceActiveFocus()
    onMediaOpenChanged: if (mediaOpen) keys.forceActiveFocus()

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

            WidgetSlot { names: Config.widgets.left; shown: win.widgetsShown; anchors.verticalCenter: parent.verticalCenter }
            LangWidget { anchors.verticalCenter: parent.verticalCenter }
            Workspaces { screen: win.screen; anchors.verticalCenter: parent.verticalCenter }
            Clock { anchors.verticalCenter: parent.verticalCenter }
            Weather {
                anchors.verticalCenter: parent.verticalCenter
                open: win.panelHere && Panels.panel === "weather"
            }
            WidgetSlot { names: Config.widgets.right; shown: win.widgetsShown; anchors.verticalCenter: parent.verticalCenter }
            VolumeOsd { anchors.verticalCenter: parent.verticalCenter }
            NotifyOsd { visible: !win.notifSide && width > 0.5; anchors.verticalCenter: parent.verticalCenter }
            ControlButton { anchors.verticalCenter: parent.verticalCenter; open: win.panelHere && Panels.panel === "control" }
        }

        Loader {
            id: panelLoader
            x: win.ear
            y: win.barH
            // follow the body as it grows or shrinks, so a panel's content never draws outside the black shape
            width: Math.min(win.bodyW, shape.width - 2 * win.ear)
            height: Math.min(win.panelH, Math.max(0, shape.height - win.barH))
            active: win.panelHere
            clip: true
            sourceComponent: Panels.panel === "control" ? controlPanel
                           : Panels.panel === "switcher" ? switcherPanel
                           : Panels.panel === "windows" ? windowsPanel
                           : Panels.panel === "weather" ? weatherPanel
                           : Panels.panel === "calendar" ? calendarPanel
                           : Panels.panel === "launcher" ? launcherPanel : null
        }
    }

    // a notification in side mode: its own pill next to the notch (the activities make room), the notch stays put
    NotifyOsd {
        id: popup
        pill: true
        visible: win.notifSide && width > 0.5
        x: shape.x + shape.width + 8
        y: win.floating ? win.topGap : 4
    }

    // what is switched on right now, right or left of the notch (activities.side), in one round pill or as separate
    // circles (activities.style)
    Rectangle {
        id: activity
        readonly property bool circles: Config.activities.style === "circles"
        readonly property real size: win.floating ? win.barH : win.barH - 8
        readonly property real pad: (size - 22) / 2
        readonly property color back: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Config.notch.opacity)
        readonly property real shift: win.notifSide && Config.activities.side !== "left" && popup.width > 0.5 ? popup.width + 8 : 0
        x: Config.activities.side === "left" ? shape.x - 8 - width : shape.x + shape.width + 8 + shift
        y: win.floating ? win.topGap : 4
        height: size
        width: acts.count > 0 ? (circles ? acts.implicitWidth : acts.implicitWidth + 2 * pad) : 0
        radius: size / 2
        opacity: acts.count > 0 ? 1 : 0
        visible: opacity > 0
        color: circles ? "transparent" : back

        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Indicators {
            id: acts
            x: activity.circles ? 0 : activity.pad
            pad: activity.circles ? activity.pad : 0
            backing: activity.circles ? activity.back : "transparent"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Component { id: controlPanel; ControlPanel {} }
    Component { id: switcherPanel; Switcher { maxWidth: win.width - 160 } }
    Component { id: windowsPanel; WindowSwitcher { maxWidth: win.width - 160 } }
    Component { id: weatherPanel; WeatherPanel {} }
    Component { id: calendarPanel; CalendarPanel {} }
    Component { id: launcherPanel; Launcher {} }
}
