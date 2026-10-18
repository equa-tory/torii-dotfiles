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
    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1

    property var ids: []
    // special workspaces that hold windows (or are open here), e.g. "special:magic"; minimized ones live in Alt+Tab
    property var specials: []
    readonly property string openSpecial: {
        const o = mon ? mon.lastIpcObject : null;
        return o && o.specialWorkspace ? o.specialWorkspace.name : "";
    }

    spacing: 6

    function find(id) {
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].id === id)
                return list[i];
        return null;
    }

    // ids 1..count on every monitor (even when the workspace is pinned to another one) + extra ids living here
    function compute() {
        const out = [];
        const list = Hyprland.workspaces.values;
        const count = Config.workspaces.count;
        for (let id = 1; id <= count; id++)
            out.push(id);
        for (let i = 0; i < list.length; i++) {
            const ws = list[i];
            if (ws.id > count && mon && ws.monitor === mon)
                out.push(ws.id);
        }
        out.sort((x, y) => x - y);
        return out;
    }

    function computeSpecials() {
        const out = [];
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++) {
            const n = list[i].name;
            if (list[i].id >= 0 || n.indexOf("special:") !== 0 || n === "special:minimized")
                continue;
            if (list[i].toplevels.values.length > 0 || n === openSpecial)
                out.push(n);
        }
        out.sort();
        return out;
    }

    function refresh() {
        const next = compute();
        if (JSON.stringify(next) !== JSON.stringify(ids))
            ids = next;
        const sp = computeSpecials();
        if (JSON.stringify(sp) !== JSON.stringify(specials))
            specials = sp;
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
            readonly property bool active: modelData === root.activeId || modelData === root.focusedId
            readonly property bool focused: modelData === root.focusedId
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
                color: cell.active ? (cell.focused ? Theme.accent : Theme.accentDim)
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

    // special workspaces: outlined while hidden, filled while open on this monitor
    Repeater {
        model: root.specials

        delegate: Item {
            id: sp
            required property string modelData
            readonly property bool open: modelData === root.openSpecial

            width: 15
            height: 22
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            Rectangle {
                anchors.centerIn: parent
                width: sp.open ? 14 : 12
                height: width
                radius: width / 2
                color: sp.open ? Theme.accent : "transparent"
                border.width: sp.open ? 0 : 1.5
                border.color: Theme.subtle

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 180 } }

                // a window lives here: dot in the ring
                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: 2
                    color: sp.open ? Theme.accentFg : Theme.subtle
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -2
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch('hl.dsp.workspace.toggle_special("' + sp.modelData.substring(8) + '")')
            }
        }
    }
}
