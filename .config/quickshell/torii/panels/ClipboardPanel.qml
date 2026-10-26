import qs
import qs.widgets
import qs.services
import Quickshell
import QtQuick

// Clipboard history (Super+V). Type to filter, Up/Down choose, Enter pastes into the window underneath, Delete forgets
// the chosen entry, Ctrl+Delete forgets everything. torii-clip keeps the list (cliphist records it).
Item {
    id: root

    property var items: []
    property int sel: 0
    readonly property string bin: Config.home + "/.config/torii/bin/torii-clip"
    readonly property var shown: {
        const q = search.text.trim().toLowerCase();
        return items.filter(e => q === "" || e.text.toLowerCase().indexOf(q) >= 0).slice(0, 8);
    }
    readonly property real rowH: 34

    implicitWidth: 460
    implicitHeight: 54 + Math.max(1, shown.length) * rowH + 10

    opacity: 0
    Component.onCompleted: { opacity = 1; fetch.refresh(); search.forceActiveFocus(); }
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    onShownChanged: sel = Math.min(sel, Math.max(0, shown.length - 1))

    JsonFetch {
        id: fetch
        command: [root.bin, "list"]
        onDataChanged: if (data) root.items = data
    }

    function pick(e) {
        if (!e) return;
        Quickshell.execDetached([bin, "paste", e.id]);
        Panels.close();
    }
    function clearAll() { Quickshell.execDetached([bin, "clear"]); items = []; search.forceActiveFocus(); }
    function forget(e) {
        if (!e) return;
        Quickshell.execDetached([bin, "delete", e.id]);
        items = items.filter(x => x.id !== e.id);
    }

    Rectangle {
        x: 18; y: 4
        width: parent.width - 36
        height: 36
        radius: 10
        color: Theme.surface

        Glyph { x: 12; anchors.verticalCenter: parent.verticalCenter; text: Icons.g(0xF0147); color: Theme.accent }
        TextInput {
            id: search
            anchors { left: parent.left; right: parent.right; leftMargin: 40; rightMargin: root.items.length > 0 ? 80 : 12; verticalCenter: parent.verticalCenter }
            color: Theme.fg
            selectionColor: Theme.accent
            font.pixelSize: Config.font.size
            clip: true
            onTextChanged: root.sel = 0
            Keys.onUpPressed: root.sel = Math.max(0, root.sel - 1)
            Keys.onDownPressed: root.sel = Math.min(root.shown.length - 1, root.sel + 1)
            Keys.onReturnPressed: root.pick(root.shown[root.sel])
            Keys.onEscapePressed: Panels.close()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ControlModifier)) {
                    root.clearAll(); event.accepted = true;
                } else if (event.key === Qt.Key_Delete && text === "") {
                    root.forget(root.shown[root.sel]); event.accepted = true;
                }
            }
            Connections {
                target: Panels
                function onEditRequested(action) {
                    if (action === "paste") search.paste();
                    else if (action === "selectall") search.selectAll();
                    else if (action === "copy") search.copy();
                    else if (action === "cut") search.cut();
                    else if (action === "undo") search.undo();
                }
            }
            Label {
                visible: search.text === ""
                text: root.items.length === 0 ? "Nothing copied yet" : "Clipboard history  ·  Enter pastes  ·  Del forgets"
                color: Theme.muted
                font: search.font
            }
        }
    }

    // forget everything (same as Ctrl+Delete)
    Rectangle {
        visible: root.items.length > 0
        x: 18 + parent.width - 36 - width - 6; y: 8
        width: clearLabel.implicitWidth + 16; height: 28; radius: 8
        color: clearArea.containsMouse ? Theme.surface2 : "transparent"
        Label { id: clearLabel; anchors.centerIn: parent; text: "Clear all"; color: clearArea.containsMouse ? Theme.red : Theme.subtle; font.pixelSize: Config.font.size - 1 }
        MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clearAll() }
    }

    Column {
        x: 18; y: 48
        width: parent.width - 36
        Repeater {
            model: root.shown
            ListRow {
                width: parent.width
                implicitHeight: root.rowH
                glyph: modelData.image ? Icons.g(0xF02E9) : Icons.g(0xF0147)
                title: modelData.text
                current: index === root.sel
                onClicked: root.pick(modelData)
                IconButton {
                    glyph: Icons.close
                    onClicked: root.forget(modelData)
                }
            }
        }
    }
}
