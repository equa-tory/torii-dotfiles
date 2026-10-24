import qs
import Quickshell
import Quickshell.Hyprland
import QtQuick

// Letter workspaces (Alt+W, then the letter; chosen per app in Setup > App rules > Workspace): one small pill per letter, left of the numbered
// workspaces. A letter shows while an app rule uses it or a window lives on it. Event driven, like Workspaces.
Row {
    id: root

    required property var screen
    readonly property var mon: Hyprland.monitorFor(screen)
    readonly property string activeName: mon && mon.activeWorkspace ? mon.activeWorkspace.name : ""
    readonly property string focusedName: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.name : ""
    property var letters: []
    property bool picking: false          // Alt+W / Alt+Shift+W is waiting for the letter

    spacing: 4
    readonly property bool present: letters.length > 0
    visible: present

    function refresh() {
        const out = [];
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++)
            if (/^[a-z]$/.test(list[i].name))
                out.push(list[i].name);
        out.sort();
        if (JSON.stringify(out) !== JSON.stringify(letters))
            letters = out;
    }
    function find(name) {
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].name === name)
                return list[i];
        return null;
    }

    Timer { id: debounce; interval: 40; onTriggered: root.refresh() }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "fullscreen" || event.name === "openwindow" || event.name === "closewindow" || event.name === "movewindowv2") Hyprland.refreshWorkspaces();
            if (event.name === "submap") root.picking = event.data === "wsgo" || event.data === "wsmove";
            debounce.restart();
        }
    }
    Component.onCompleted: refresh()

    Repeater {
        model: root.letters
        delegate: Rectangle {
            id: pill
            required property string modelData
            readonly property var ws: root.find(modelData)
            readonly property bool active: modelData === root.activeName || modelData === root.focusedName
            readonly property bool focused: modelData === root.focusedName
            readonly property bool occupied: ws ? ws.toplevels.values.length > 0 : false
            readonly property bool fullscreen: ws && ws.lastIpcObject ? ws.lastIpcObject.hasfullscreen === true : false

            width: Math.max(20, txt.implicitWidth + 10)
            height: 20
            radius: 10
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            color: active ? (focused ? Theme.accent : Theme.accentDim) : (occupied ? Theme.subtle : Theme.overlay)
            border.width: root.picking ? 1.5 : 0
            border.color: root.picking ? Theme.accent : Theme.overlay
            Behavior on color { ColorAnimation { duration: 180 } }

            Text {
                id: txt
                anchors.centerIn: parent
                text: pill.modelData.toUpperCase()
                font.family: Config.font.family
                font.pixelSize: Config.font.size - 2
                font.bold: true
                color: pill.active ? Theme.accentFg : Theme.bg
            }
            // a window on this workspace is fullscreen (it hides the others, so it is easy to lose): the letter is underlined
            Rectangle {
                visible: pill.fullscreen
                anchors.horizontalCenter: parent.horizontalCenter
                y: txt.y + txt.height - 1
                width: txt.implicitWidth
                height: 2
                radius: 1
                color: txt.color
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // the letter workspace comes to this monitor (like Alt+W), it does not send you to the one it was last on
                    if (root.mon) Hyprland.dispatch('hl.dsp.workspace.move({ workspace = "name:' + pill.modelData + '", monitor = "' + root.mon.name + '" })');
                    Hyprland.dispatch('hl.dsp.focus({ workspace = "name:' + pill.modelData + '" })');
                }
            }
        }
    }
}
