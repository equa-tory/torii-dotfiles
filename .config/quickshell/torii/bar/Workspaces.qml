import qs
import Quickshell
import Quickshell.Hyprland
import QtQuick

// Vertical capsules for the workspaces of ONE monitor. Event driven (Hyprland socket), no polling.
Row {
    id: root

    required property var screen
    readonly property var mon: Hyprland.monitorFor(screen)
    readonly property bool monFocused: mon ? mon.focused : false
    readonly property int activeId: mon && mon.activeWorkspace ? mon.activeWorkspace.id : -1

    property var ids: []
    readonly property bool special: {
        const o = mon ? mon.lastIpcObject : null;
        return !!(o && o.specialWorkspace && o.specialWorkspace.name);
    }

    spacing: 6

    function find(id) {
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].id === id)
                return list[i];
        return null;
    }

    // ids 1..count (unless they live on another monitor) + anything occupied or active here
    function compute() {
        const out = [];
        const list = Hyprland.workspaces.values;
        const count = Config.workspaces.count;
        for (let id = 1; id <= count; id++) {
            const ws = find(id);
            if (!ws || !mon || ws.monitor === mon)
                out.push(id);
        }
        for (let i = 0; i < list.length; i++) {
            const ws = list[i];
            if (ws.id > count && mon && ws.monitor === mon)
                out.push(ws.id);
        }
        out.sort((x, y) => x - y);
        return out;
    }

    function refresh() {
        const next = compute();
        if (JSON.stringify(next) !== JSON.stringify(ids))
            ids = next;
    }

    Timer {
        id: debounce
        interval: 40
        onTriggered: {
            root.refresh();
            Hyprland.refreshMonitors();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) { debounce.restart(); }
    }
    Connections {
        target: Config.workspaces
        function onCountChanged() { root.refresh(); }
    }
    Component.onCompleted: refresh()

    Repeater {
        model: root.ids

        delegate: Item {
            id: cell
            required property int modelData
            readonly property var ws: root.find(modelData)
            readonly property bool active: modelData === root.activeId
            readonly property bool occupied: ws ? ws.toplevels.values.length > 0 : false

            width: capsule.width
            height: 22
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            Rectangle {
                id: capsule
                anchors.centerIn: parent
                width: cell.active ? 10 : 7
                height: cell.active ? 22 : 15
                radius: width / 2
                color: cell.active ? (root.monFocused ? Theme.accent : Theme.accentDim)
                       : cell.occupied ? Theme.subtle : Theme.overlay

                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 180 } }

                // marker: a window lives here
                Rectangle {
                    visible: cell.occupied
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    width: 3
                    height: 3
                    radius: 1.5
                    color: cell.active ? Theme.accentFg : Theme.bg
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -3
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (cell.ws)
                        cell.ws.activate();
                    else
                        Hyprland.dispatch('hl.dsp.focus({ workspace = "' + cell.modelData + '" })');
                }
            }
        }
    }

    // the "magic" special workspace is open on this monitor
    Rectangle {
        visible: root.special
        anchors.verticalCenter: parent.verticalCenter
        width: 7
        height: 7
        radius: 3.5
        color: Theme.accent

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: Hyprland.dispatch('hl.dsp.workspace.toggle_special("magic")')
        }
    }
}
