import qs
import qs.services
import qs.widgets
import Quickshell
import QtQuick
import "../widgets/calc.js" as Calc
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
    // a menu can ask for a grid (emoji): arrows then move in two dimensions
    readonly property bool gridMode: scope !== null && scope.grid === true
    readonly property int cols: 10
    readonly property real cell: 52
    readonly property int gridRows: 6

    implicitWidth: 560
    implicitHeight: 66 + (showNotice ? 26 : 0) + (showList ? (gridMode ? Math.min(Math.ceil(results.length / cols), gridRows) * cell + 40 : Math.min(results.length, maxRows) * rowH + 14) : 0)

    opacity: 0
    Timer { running: true; interval: 380; onTriggered: root.hintShown = true }
    Component.onCompleted: {
        opacity = 1;
        Apps.refresh();
        Menus.invalidate();
        Menus.endPrompt();
        if (Panels.launcherPath.length) { pathIds = Panels.launcherPath; Panels.launcherPath = []; expanded = true; }
        update(false);
        input.forceActiveFocus();
    }
    Component.onDestruction: { Menus.endPrompt(); }
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // right click: one menu back, then collapse
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: { if (root.asking) Menus.endPrompt(); else if (root.pathIds.length) root.back(); else if (root.expanded) root.expanded = false; }
    }

    // a quicklink icon of a single character is a font glyph, anything longer is an icon name or an image path
    function glyphOf(i) { return i && i.length <= 2 && String.fromCodePoint(i.codePointAt(0)) === i ? i : ""; }

    function linkNode(link) {
        return { id: "link:" + link.keyword, name: link.title, sub: link.sub, glyph: glyphOf(link.icon) || Icons.link, icon: glyphOf(link.icon) ? undefined : (link.icon || undefined),
                 run: () => Apps.run({ kind: "link", url: link.url }) };
    }

    // rebuild the list; keepSel keeps the highlighted row when only the data changed
    // while a slider is being dragged the rows must not be rebuilt (the mouse grab would be lost)
    // the mouse only counts after it really moved (a cursor resting under a fresh or scrolling list does nothing),
    // and not any more after the next key press
    property bool mouseLive: false
    property real lastMx: -1
    property real lastMy: -1
    function mouseMoved(item, x, y) {
        const p = item.mapToItem(root, x, y);
        if (lastMx < 0) { lastMx = p.x; lastMy = p.y; return mouseLive; }
        if (Math.abs(p.x - lastMx) + Math.abs(p.y - lastMy) >= 3) { mouseLive = true; lastMx = p.x; lastMy = p.y; }
        return mouseLive;
    }

    property bool dragging: false
    property bool dirty: false
    onDraggingChanged: if (!dragging && dirty) { dirty = false; update(true); }

    function update(keepSel) {
        if (dragging) { dirty = true; return; }
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
                const calc = Calc.evaluate(q);
                if (calc.ok) out.push({ node: { id: "calc", name: "= " + calc.text, sub: q + "  ·  Enter copies the result", glyph: Icons.calc,
                    run: () => Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy && notify-send -a torii -t 2500 "Copied" "$1"', "sh", calc.text]) }, trail: [] });
                const link = Quicklinks.resolve(q);
                if (link) out.push({ node: linkNode(link), trail: [] });
                if (link && /\s/.test(q)) { results = out; selected = 0; return; }   // "yt cats" is a search, not a lookup
            }
            out = out.concat(Menus.search(scope, q, pathIds));
            if (!scope && out.length === 0) {
                const g = Quicklinks.resolve("ddg " + q);
                if (g) out.push({ node: linkNode(g), trail: [] });
            }
        }
        results = out.slice(0, gridMode ? 500 : 40);
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
    // Alt+A/C/V/X/Z and Super+Left/Right arrive here from Hyprland (it would send them to the window underneath)
    Connections {
        target: Panels
        function onEditRequested(action) {
            if (action === "copy") input.copy();
            else if (action === "paste") input.paste();
            else if (action === "cut") input.cut();
            else if (action === "undo") input.undo();
            else if (action === "selectall") input.selectAll();
            else if (action === "home") { input.deselect(); input.cursorPosition = 0; }
            else if (action === "end") { input.deselect(); input.cursorPosition = input.text.length; }
            else if (action === "selecthome") input.select(input.cursorPosition, 0);
            else if (action === "selectend") input.select(input.cursorPosition, input.text.length);
        }
    }
    Connections { target: Menus; function onPromptChanged() { input.text = ""; root.update(false); } }

    // ---- actions
    function move(d) {
        mouseLive = false;
        if (results.length === 0) return;
        selected = Math.max(0, Math.min(results.length - 1, selected + d));      // no wrapping: the ends are the ends
        ensureVisible(false);
        remember();
    }
    function jump(to) {
        mouseLive = false;
        if (results.length === 0) return;
        selected = Math.max(0, Math.min(results.length - 1, to));
        ensureVisible(false);
        remember();
    }

    // keep the selected row, and one row more on each side, in view; the list glides there
    function ensureVisible(instant) {
        if (gridMode) { grid.positionViewAtIndex(selected, GridView.Contain); return; }
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
    function setSlider(n, v) {
        const sl = n.slider;
        // a slider with `values` (monitor scale) only has those stops: drag to the nearest one
        if (sl.values && sl.values.length) v = sl.values.reduce((b, x) => Math.abs(x - v) < Math.abs(b - v) ? x : b, sl.values[0]);
        else v = Math.round(v / sl.step) * sl.step;
        v = Math.max(sl.min, Math.min(sl.max, v));
        v = Number(v.toFixed(sl.decimals || 0));
        pending = { id: n.id, value: v };
        commit.node = n; commit.value = v; commit.restart();
        clearPending.restart();
    }
    function adjust(dir, big) {
        const n = selectedSlider();
        if (!n) return;
        const vals = n.slider.values;
        if (vals && vals.length) {          // arrow keys walk the stops, one per press
            const cur = sliderValue(n);
            const next = dir > 0 ? vals.filter(x => x > cur + 1e-6) : vals.filter(x => x < cur - 1e-6).reverse();
            if (next.length) setSlider(n, next[Math.min(next.length - 1, big ? 2 : 0)]);
        } else setSlider(n, sliderValue(n) + dir * n.slider.step * (big ? 5 : 1));
    }
    Timer { id: commit; interval: 130; property var node: null; property real value: 0
           onTriggered: if (node) node.onSlide(value) }
    Timer { id: clearPending; interval: 1400; onTriggered: root.pending = null }

    function enter(node, chain) {
        remember();
        if (node.onOpen) node.onOpen();
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
                onTextChanged: { root.mouseLive = false; if (!root.asking) { root.update(false); } }

                Keys.onDownPressed: event => {
                    if (root.asking) return;
                    if (!root.showList) { if (root.results.length) { root.expanded = true; root.selected = 0; } }
                    else root.move(root.gridMode ? root.cols : 1);
                }
                Keys.onUpPressed: event => {
                    if (root.asking) return;
                    if (root.gridMode && root.selected >= root.cols) { root.move(-root.cols); return; }
                    if (input.text.trim() === "" && root.expanded && root.selected < (root.gridMode ? root.cols : 1)) root.expanded = false;
                    else if (!root.gridMode) root.move(-1);
                    else root.jump(0);
                }
                Keys.onTabPressed: root.move(1)
                Keys.onBacktabPressed: root.move(-1)
                Keys.onReturnPressed: root.asking ? root.submitPrompt() : root.activate(false)
                Keys.onEnterPressed: root.asking ? root.submitPrompt() : root.activate(false)
                Keys.onEscapePressed: { if (root.asking) Menus.endPrompt(); else Panels.close(); }
                Keys.onRightPressed: event => {
                    if (!root.asking && root.gridMode && root.showList) { root.move(1); return; }
                    if (!root.asking && root.selectedSlider() && root.showList) { root.adjust(1, event.modifiers & Qt.ShiftModifier); return; }
                    if (root.asking || input.cursorPosition < input.text.length) { event.accepted = false; return; }
                    if (!root.showList) { if (input.text === "" && root.results.length) { root.expanded = true; root.selected = 0; } }
                    else root.activate(true);
                }
                Keys.onLeftPressed: event => {
                    if (!root.asking && root.gridMode && root.showList && root.selected > 0) { root.move(-1); return; }
                    if (!root.asking && root.selectedSlider() && root.showList) { root.adjust(-1, event.modifiers & Qt.ShiftModifier); return; }
                    if (input.cursorPosition > 0 || input.selectionStart !== input.selectionEnd) { event.accepted = false; return; }
                    if (root.asking) { Menus.endPrompt(); return; }
                    if (input.text !== "") return;
                    if (root.pathIds.length) root.back();
                    else if (root.expanded) root.expanded = false;
                    else Panels.close();
                }
                Keys.onPressed: event => {
                    root.mouseLive = false;
                    if (root.showList && !root.asking) {
                        if (event.key === Qt.Key_PageDown) { root.jump(root.selected + (root.gridMode ? root.cols * root.gridRows : root.maxRows - 1)); event.accepted = true; return; }
                        if (event.key === Qt.Key_PageUp) { root.jump(root.selected - (root.gridMode ? root.cols * root.gridRows : root.maxRows - 1)); event.accepted = true; return; }
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
        font.pixelSize: Config.font.size - 1
        elide: Text.ElideRight
    }

    // a soft glow at the top / bottom edge of the list when there is more to scroll to that way
    Rectangle {
        readonly property bool more: root.showList && !root.gridMode && list.contentY > 4
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
        readonly property bool more: root.showList && !root.gridMode && list.contentHeight - list.height - list.contentY > 4
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
        visible: root.showList && !root.gridMode && root.results.length > root.maxRows
        x: parent.width - 9
        y: list.y + 4 + (list.height - 8 - height) * (list.contentHeight - list.height > 0 ? list.contentY / (list.contentHeight - list.height) : 0)
        width: 3
        height: Math.max(24, (list.height - 8) * list.height / Math.max(1, list.contentHeight))
        radius: 1.5
        color: Theme.muted
        z: 5
    }

    // ---- emoji grid
    GridView {
        id: grid
        visible: root.showList && root.gridMode
        anchors { left: parent.left; right: parent.right; top: root.showNotice ? notice.bottom : field.bottom; topMargin: 8; leftMargin: 14 + (root.width - 28 - root.cols * root.cell) / 2; rightMargin: 14 + (root.width - 28 - root.cols * root.cell) / 2 }
        height: Math.min(Math.ceil(root.results.length / root.cols), root.gridRows) * root.cell
        cellWidth: root.cell
        cellHeight: root.cell
        model: root.gridMode ? root.results : []
        clip: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0

        delegate: Item {
            required property var modelData
            required property int index
            width: root.cell
            height: root.cell
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: 10
                color: index === root.selected ? Theme.surface2 : "transparent"
                border.width: index === root.selected ? 1 : 0
                border.color: Theme.accent
            }
            Text {
                anchors.centerIn: parent
                text: modelData.node.glyph
                font.pixelSize: 26
                renderType: Text.CurveRendering
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: mouse => { if (root.mouseMoved(this, mouse.x, mouse.y)) root.selected = index; }
                onClicked: { root.selected = index; root.activate(false); }
            }
        }
    }
    Label {
        visible: root.showList && root.gridMode && root.results[root.selected] !== undefined
        anchors { left: parent.left; right: parent.right; top: grid.bottom; topMargin: 6; leftMargin: 28; rightMargin: 28 }
        text: root.results[root.selected] ? root.results[root.selected].node.name + (root.results[root.selected].node.sub ? "  ·  " + root.results[root.selected].node.sub : "") : ""
        color: Theme.fgDim
        font.pixelSize: Config.font.size - 1
        elide: Text.ElideRight
    }

    // ---- results
    ListView {
        id: list
        visible: root.showList && !root.gridMode
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
                            return i.charAt(0) === "/" ? "file://" + i + "?" + Quicklinks.iconRev : Quickshell.iconPath(i, true);
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
                        id: sliderBar
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
                        font.pixelSize: Config.font.size - 1
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
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: row.node.slider !== undefined
                cursorShape: Qt.PointingHandCursor
                // a slider row is dragged: press or move along the bar sets the value
                function drag(mx) {
                    const x = sliderBar.mapFromItem(rowMouse, mx, 0).x;
                    const sl = row.node.slider;
                    root.setSlider(row.node, sl.min + (sl.max - sl.min) * Math.max(0, Math.min(1, x / sliderBar.width)));
                }
                onPressed: mouse => { root.selected = row.index; if (row.node.slider) { root.dragging = true; drag(mouse.x); } }
                onReleased: root.dragging = false
                onCanceled: root.dragging = false
                onPositionChanged: mouse => {
                    if (pressed && row.node.slider) drag(mouse.x);
                    else if (root.mouseMoved(rowMouse, mouse.x, mouse.y) && root.selected !== row.index) { root.selected = row.index; root.remember(); }
                }
                onClicked: { root.selected = row.index; if (!row.node.slider) root.activate(false); }
            }
        }
    }
}
