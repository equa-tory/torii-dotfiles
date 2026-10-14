import qs
import qs.services
import qs.widgets
import Quickshell
import QtQuick
import QtQuick.Layouts

// Keyboard-first launcher. Opens as just the input; Down shows the menus, Right enters / runs, Left goes back / closes.
// Typing searches every menu and submenu at once (inside a submenu: that submenu). `yt cats` style quicklinks work at the top.
Item {
    id: root

    readonly property int maxRows: 9
    readonly property real rowH: 46
    property var pathIds: []              // ids of the menus we are inside of
    property var path: []                 // those menus as nodes, rebuilt on every update so they never go stale
    property bool expanded: false
    property var results: []              // [{ node, trail }]
    property int selected: 0
    property string lastNav: "other"      // how the list was reached: back | forward | other
    property bool hintShown: false        // the placeholder fades in a moment after the launcher has opened
    property var pending: null            // slider value shown while a change is on its way: { id, value }

    readonly property var scope: path.length ? path[path.length - 1] : null
    readonly property bool asking: Menus.prompt !== null
    readonly property bool showList: !asking && results.length > 0 && (expanded || input.text.trim() !== "")
    readonly property bool showNotice: Menus.notice !== ""

    implicitWidth: 560
    implicitHeight: 66 + (showNotice ? 26 : 0) + (showList ? Math.min(results.length, maxRows) * rowH + 14 : 0)

    opacity: 0
    Timer { running: true; interval: 380; onTriggered: root.hintShown = true }
    Component.onCompleted: {
        opacity = 1;
        Apps.refresh();
        Menus.invalidate();
        Menus.endPrompt();
        update(false);
        input.forceActiveFocus();
    }
    Component.onDestruction: { Menus.endPrompt(); }
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    function linkNode(link) {
        return { id: "link:" + link.keyword, name: link.title, sub: link.sub, glyph: Icons.link,
                 run: () => Apps.run({ kind: "link", url: link.url }) };
    }

    // rebuild the list; keepSel keeps the highlighted row when only the data changed
    function update(keepSel) {
        if (asking) { results = []; return; }
        path = Menus.resolve(pathIds);
        if (path.length < pathIds.length) pathIds = pathIds.slice(0, path.length);
        const q = input.text.trim();
        const prev = keepSel && results[selected] ? results[selected].node.id : null;
        let out = [];

        if (q === "") {
            out = Menus.childrenOf(scope).map(n => ({ node: n, trail: [] }));
        } else if (q.charAt(0) === ":" && !scope) {
            out = q.length > 1 ? Menus.emojiSearch(q.slice(1)) : [];
        } else {
            if (!scope) {
                const link = Quicklinks.resolve(q);
                if (link) out.push({ node: linkNode(link), trail: [] });
                if (link && /\s/.test(q)) { results = out; selected = 0; return; }   // "yt cats" is a search, not a lookup
            }
            out = out.concat(Menus.search(scope, q, pathIds));
            if (!scope && out.length === 0) {
                const g = Quicklinks.resolve("g " + q);
                if (g) out.push({ node: linkNode(g), trail: [] });
            }
        }
        results = out.slice(0, 40);
        const at = prev === null ? -1 : results.findIndex(r => r.node.id === prev);
        selected = at >= 0 ? at : Math.min(selected, Math.max(0, results.length - 1));
        if (!keepSel) {
            // back in a menu: land on the row you were on last time
            const allowed = lastNav === "back" ? Config.launcher.rememberBack : Config.launcher.rememberForward;
            const want = (q === "" && allowed) ? Menus.memory[pathIds.join("/")] : undefined;
            const at2 = want === undefined ? -1 : results.findIndex(r => r.node.id === want);
            selected = at2 >= 0 ? at2 : 0;
            ensureVisible(true);
            lastNav = "other";
        }
    }

    function remember() {
        if (input.text.trim() !== "" || !results[selected]) return;
        const m = Object.assign({}, Menus.memory);
        m[pathIds.join("/")] = results[selected].node.id;
        Menus.memory = m;
    }

    Connections { target: Menus; function onRevChanged() { root.update(true); } }
    Connections { target: Apps; function onPortableChanged() { root.update(true); } }
    Connections { target: Quicklinks; function onLinksChanged() { root.update(true); } }
    Connections { target: Menus; function onPromptChanged() { input.text = ""; root.update(false); } }

    // ---- actions
    function move(d) {
        if (results.length === 0) return;
        selected = Math.max(0, Math.min(results.length - 1, selected + d));      // no wrapping: the ends are the ends
        ensureVisible(false);
        remember();
    }
    function jump(to) {
        if (results.length === 0) return;
        selected = Math.max(0, Math.min(results.length - 1, to));
        ensureVisible(false);
        remember();
    }

    // keep the selected row, and one row more on each side, in view; the list glides there
    function ensureVisible(instant) {
        const margin = 1;
        const maxY = Math.max(0, list.contentHeight - list.height);
        let y = list.contentY;
        const top = (selected - margin) * rowH;
        const bottom = (selected + 1 + margin) * rowH - list.height;
        if (top < y) y = top; else if (bottom > y) y = bottom;
        y = Math.max(0, Math.min(maxY, y));
        scrollAnim.stop();
        if (instant) { list.contentY = y; return; }
        scrollAnim.to = y;
        scrollAnim.restart();
    }
    NumberAnimation { id: scrollAnim; target: list; property: "contentY"; duration: 160; easing.type: Easing.OutCubic }

    // ---- sliders (night light temperature, mouse speed): Left/Right change them while the row is selected
    function sliderValue(n) { return pending && pending.id === n.id ? pending.value : n.slider.value; }
    function sliderText(n) { const v = sliderValue(n); return v.toFixed(n.slider.decimals || 0) + (n.slider.unit || ""); }
    function selectedSlider() { return results[selected] && results[selected].node.slider ? results[selected].node : null; }
    function adjust(dir, big) {
        const n = selectedSlider();
        if (!n) return;
        const sl = n.slider;
        let v = sliderValue(n) + dir * sl.step * (big ? 5 : 1);
        v = Math.max(sl.min, Math.min(sl.max, Math.round(v / sl.step) * sl.step));
        v = Number(v.toFixed(sl.decimals || 0));
        pending = { id: n.id, value: v };
        commit.node = n; commit.value = v; commit.restart();
        clearPending.restart();
    }
    Timer { id: commit; interval: 130; property var node: null; property real value: 0
           onTriggered: if (node) node.onSlide(value) }
    Timer { id: clearPending; interval: 1400; onTriggered: root.pending = null }

    function enter(node, chain) {
        remember();
        Menus.touch((chain || pathIds).concat([node.id]));
        pathIds = (chain || pathIds).concat([node.id]);
        input.text = "";
        expanded = true;
        lastNav = "forward";
        update(false);
    }

    function back() {
        remember();
        pathIds = pathIds.slice(0, -1);
        input.text = "";
        lastNav = "back";
        update(false);
    }

    function activate(right) {
        if (results.length === 0) return;
        const n = results[selected].node;
        const menu = n.children !== undefined;
        if (menu && (right || !n.run)) { enter(n, results[selected].chain); return; }
        if (!n.run) return;
        remember();
        Menus.touch((results[selected].chain || pathIds).concat([n.id]));
        n.run();
        if (!n.keep) Panels.close();
    }

    function submitPrompt() {
        const p = Menus.prompt;
        const text = p.secret ? input.text : input.text.trim();
        Menus.endPrompt();
        p.submit(text);
    }

    // ---- field
    Rectangle {
        id: field
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; topMargin: 6 }
        height: 46
        radius: 12
        color: Theme.surface

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            Glyph { text: root.scope && root.scope.glyph ? root.scope.glyph : Icons.search; size: 17; color: Theme.accent }

            Label {
                visible: root.pathIds.length > 0 && !root.asking
                text: root.path.map(n => n.name).join(" › ") + " ›"
                color: Theme.accent
            }

            TextInput {
                id: input
                Layout.fillWidth: true
                color: Theme.fg
                font.family: Config.font.family
                font.pixelSize: Config.font.size + 2
                renderType: Text.CurveRendering
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentFg
                echoMode: Menus.prompt !== null && Menus.prompt.secret ? TextInput.Password : TextInput.Normal
                clip: true
                onTextChanged: { if (!root.asking) { root.update(false); } }

                Keys.onDownPressed: event => {
                    if (root.asking) return;
                    if (!root.showList) { if (root.results.length) { root.expanded = true; root.selected = 0; } }
                    else root.move(1);
                }
                Keys.onUpPressed: event => {
                    if (root.asking) return;
                    if (input.text.trim() === "" && root.expanded && root.selected === 0) root.expanded = false;
                    else root.move(-1);
                }
                Keys.onTabPressed: root.move(1)
                Keys.onBacktabPressed: root.move(-1)
                Keys.onReturnPressed: root.asking ? root.submitPrompt() : root.activate(false)
                Keys.onEnterPressed: root.asking ? root.submitPrompt() : root.activate(false)
                Keys.onEscapePressed: { if (root.asking) Menus.endPrompt(); else Panels.close(); }
                Keys.onRightPressed: event => {
                    if (!root.asking && root.selectedSlider() && root.showList) { root.adjust(1, event.modifiers & Qt.ShiftModifier); return; }
                    if (root.asking || input.cursorPosition < input.text.length) { event.accepted = false; return; }
                    if (!root.showList) { if (input.text === "" && root.results.length) { root.expanded = true; root.selected = 0; } }
                    else root.activate(true);
                }
                Keys.onLeftPressed: event => {
                    if (!root.asking && root.selectedSlider() && root.showList) { root.adjust(-1, event.modifiers & Qt.ShiftModifier); return; }
                    if (input.cursorPosition > 0 || input.selectionStart !== input.selectionEnd) { event.accepted = false; return; }
                    if (root.asking) { Menus.endPrompt(); return; }
                    if (input.text !== "") return;
                    if (root.pathIds.length) root.back();
                    else if (root.expanded) root.expanded = false;
                    else Panels.close();
                }
                Keys.onPressed: event => {
                    if (root.showList && !root.asking) {
                        if (event.key === Qt.Key_PageDown) { root.jump(root.selected + root.maxRows - 1); event.accepted = true; return; }
                        if (event.key === Qt.Key_PageUp) { root.jump(root.selected - root.maxRows + 1); event.accepted = true; return; }
                        if (input.text === "" && event.key === Qt.Key_Home) { root.jump(0); event.accepted = true; return; }
                        if (input.text === "" && event.key === Qt.Key_End) { root.jump(root.results.length - 1); event.accepted = true; return; }
                    }
                    if (event.modifiers & Qt.ControlModifier) {
                        if (event.key === Qt.Key_J || event.key === Qt.Key_N) { root.move(1); event.accepted = true; }
                        else if (event.key === Qt.Key_K || event.key === Qt.Key_P) { root.move(-1); event.accepted = true; }
                    }
                }

                Label {
                    visible: !input.text.length
                    text: Menus.prompt !== null ? Menus.prompt.label
                        : root.scope ? "Search in " + root.scope.name
                        : Config.launcher.placeholder
                    color: Theme.muted
                    font.pixelSize: parent.font.pixelSize
                    opacity: root.hintShown ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    Label {
        id: notice
        visible: root.showNotice
        anchors { left: parent.left; right: parent.right; top: field.bottom; topMargin: 6; leftMargin: 28; rightMargin: 28 }
        text: Menus.notice
        color: Theme.accent
        font.pixelSize: Config.font.size - 2
        elide: Text.ElideRight
    }

    // a soft glow at the top / bottom edge of the list when there is more to scroll to that way
    Rectangle {
        readonly property bool more: root.showList && list.contentY > 4
        x: list.x; y: list.y; width: list.width; height: 26; z: 6
        opacity: more ? 1 : 0
        visible: opacity > 0
        radius: 10
        Behavior on opacity { NumberAnimation { duration: 160 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20) }
            GradientStop { position: 1.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.0) }
        }
    }
    Rectangle {
        readonly property bool more: root.showList && list.contentHeight - list.height - list.contentY > 4
        x: list.x; y: list.y + list.height - height; width: list.width; height: 26; z: 6
        opacity: more ? 1 : 0
        visible: opacity > 0
        radius: 10
        Behavior on opacity { NumberAnimation { duration: 160 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20) }
        }
    }

    // thin scroll bar, so a longer list is never a surprise
    Rectangle {
        visible: root.showList && root.results.length > root.maxRows
        x: parent.width - 9
        y: list.y + 4 + (list.height - 8 - height) * (list.contentHeight - list.height > 0 ? list.contentY / (list.contentHeight - list.height) : 0)
        width: 3
        height: Math.max(24, (list.height - 8) * list.height / Math.max(1, list.contentHeight))
        radius: 1.5
        color: Theme.muted
        z: 5
    }

    // ---- results
    ListView {
        id: list
        visible: root.showList
        anchors { left: parent.left; right: parent.right; top: root.showNotice ? notice.bottom : field.bottom; topMargin: 8; leftMargin: 14; rightMargin: 18 }
        height: Math.min(root.results.length, root.maxRows) * root.rowH
        model: root.results
        clip: true
        interactive: root.results.length > root.maxRows
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: root.selected
        highlightMoveDuration: 0

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property var node: modelData.node
            readonly property bool sel: index === root.selected
            readonly property bool hasIcon: iconImg.status === Image.Ready
            readonly property bool isMenu: node.children !== undefined
            readonly property string crumb: modelData.trail.length ? modelData.trail.join(" › ") : ""

            width: ListView.view.width
            height: root.rowH
            radius: 10
            color: sel ? Theme.surface2 : "transparent"

            Rectangle {
                visible: row.sel
                width: 3
                height: 18
                radius: 1.5
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                color: Theme.accent
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 12

                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28

                    Image {
                        id: iconImg
                        anchors.fill: parent
                        sourceSize: Qt.size(56, 56)
                        smooth: true
                        asynchronous: true
                        source: {
                            const i = row.node.icon;
                            if (!i) return "";
                            return i.charAt(0) === "/" ? "file://" + i : Quickshell.iconPath(i, true);
                        }
                    }
                    Glyph {
                        anchors.centerIn: parent
                        visible: !row.hasIcon
                        size: 18
                        color: row.sel ? Theme.accent : Theme.subtle
                        text: row.node.glyph ? row.node.glyph : (row.node.name || "?").charAt(0).toUpperCase()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        text: row.node.name
                        color: row.sel ? Theme.fg : Theme.fgDim
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Item {
                        visible: row.node.slider !== undefined
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            height: 4
                            radius: 2
                            color: Theme.surface2
                            Rectangle {
                                height: parent.height
                                radius: 2
                                color: row.sel ? Theme.accent : Theme.subtle
                                width: row.node.slider ? parent.width * Math.max(0, Math.min(1, (root.sliderValue(row.node) - row.node.slider.min) / (row.node.slider.max - row.node.slider.min))) : 0
                                Behavior on width { NumberAnimation { duration: 90 } }
                            }
                        }
                    }
                    Label {
                        readonly property string line: row.crumb !== "" ? row.crumb : (row.node.sub || "")
                        visible: line !== "" && row.node.slider === undefined
                        text: line
                        color: Theme.subtle
                        font.pixelSize: Config.font.size - 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Label {
                    visible: (row.node.badge || "") !== "" || row.node.slider !== undefined
                    text: row.node.slider !== undefined ? root.sliderText(row.node) : (row.node.badge || "")
                    color: Theme.accent
                }
                Glyph {
                    visible: row.isMenu
                    text: Icons.chevronRight
                    size: 15
                    color: row.sel ? Theme.fgDim : Theme.muted
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: { if (root.selected !== row.index) { root.selected = row.index; root.remember(); } }
                onClicked: { root.selected = row.index; root.activate(false); }
            }
        }
    }
}
