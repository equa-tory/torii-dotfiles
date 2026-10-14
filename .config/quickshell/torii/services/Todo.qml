pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import QtQuick

// The todo list: ~/.local/state/torii/todo.json  { "sortDone": false, "items": [{ "id", "text", "done" }] }
// Private to you (state dir, never in the dotfiles repo). Edited from the launcher's Todo menu or by hand.
Singleton {
    id: root

    property var items: []
    property bool sortDone: false

    readonly property var shown: sortDone ? items.slice().sort((a, b) => (a.done ? 1 : 0) - (b.done ? 1 : 0)) : items
    readonly property int openCount: items.filter(i => !i.done).length

    FileView {
        id: file
        path: Config.stateDir + "/todo.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const j = JSON.parse(text());
                root.items = Array.isArray(j.items) ? j.items : [];
                root.sortDone = j.sortDone === true;
            } catch (e) { root.items = []; }
        }
    }

    function save(items, sort) {
        root.items = items;
        root.sortDone = sort;
        file.setText(JSON.stringify({ sortDone: sort, items: items }, null, 2) + "\n");
    }
    function add(text) { if (text.trim() !== "") save(items.concat([{ id: String(Date.now()), text: text.trim(), done: false }]), sortDone); }
    function toggle(id) { save(items.map(i => i.id === id ? Object.assign({}, i, { done: !i.done }) : i), sortDone); }
    function edit(id, text) { if (text.trim() !== "") save(items.map(i => i.id === id ? Object.assign({}, i, { text: text.trim() }) : i), sortDone); }
    function remove(id) { save(items.filter(i => i.id !== id), sortDone); }
    function clearDone() { save(items.filter(i => !i.done), sortDone); }
    function setSortDone(on) { save(items, on); }
}
