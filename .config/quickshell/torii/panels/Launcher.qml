import qs
import qs.services
import qs.widgets
import "../widgets/fuzzy.js" as Fuzzy
import Quickshell
import QtQuick
import QtQuick.Layouts

// Keyboard-first launcher: apps, ~/apps folders, quicklinks ("yt cats", "git"). Recently used first.
Item {
    id: root

    readonly property int maxRows: 7
    readonly property real rowH: 46
    property var results: []
    property int selected: 0

    implicitWidth: 560
    implicitHeight: 70 + (results.length > 0 ? Math.min(results.length, maxRows) * rowH + 14 : 0)

    opacity: 0
    Component.onCompleted: { opacity = 1; Apps.refresh(); update(); input.forceActiveFocus(); }
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    function update() {
        const q = input.text.trim();
        const all = Apps.items();
        let out = [];

        if (q === "") {
            // nothing typed: only what you used lately, most recent first (empty on a fresh install)
            out = all.filter(i => Apps.recents[i.key]).sort((a, b) => Apps.recents[b.key].last - Apps.recents[a.key].last);
        } else {
            const link = Quicklinks.resolve(q);
            if (link) out.push({ kind: "link", key: "link:" + link.keyword, name: link.title, sub: link.sub, url: link.url, icon: "" });
            // "yt cats": that is a search, not an app lookup
            if (link && /\s/.test(q)) { results = out; selected = 0; return; }

            const scored = [];
            for (const i of all) {
                const s = Fuzzy.scoreFields(q, [
                    { text: i.name, weight: 1 },
                    { text: i.sub, weight: 0.45 },
                    { text: i.extra, weight: 0.6 }
                ]);
                if (s >= 0) scored.push({ item: i, score: s + Apps.boost(i.key) });
            }
            scored.sort((a, b) => b.score - a.score);
            out = out.concat(scored.map(s => s.item));

            if (out.length === 0) {
                const g = Quicklinks.resolve("g " + q);
                if (g) out.push({ kind: "link", key: "link:g", name: "Search the web: " + q, sub: g.sub, url: g.url, icon: "" });
            }
        }
        results = out.slice(0, 30);
        selected = 0;
        list.positionViewAtBeginning();
    }

    function run() {
        if (results.length === 0) return;
        const item = results[selected];
        Panels.close();
        Apps.run(item);
    }

    function move(d) {
        if (results.length === 0) return;
        selected = (selected + d + results.length) % results.length;
        list.positionViewAtIndex(selected, ListView.Contain);
    }

    Connections { target: Apps; function onPortableChanged() { root.update(); } }
    Connections { target: Quicklinks; function onLinksChanged() { root.update(); } }

    // ---- search field
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
            spacing: 12

            Glyph { text: Icons.search; size: 17; color: Theme.accent }

            TextInput {
                id: input
                Layout.fillWidth: true
                color: Theme.fg
                font.family: Config.font.family
                font.pixelSize: Config.font.size + 2
                renderType: Text.CurveRendering
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentFg
                clip: true
                onTextChanged: root.update()
                Keys.onDownPressed: root.move(1)
                Keys.onUpPressed: root.move(-1)
                Keys.onTabPressed: root.move(1)
                Keys.onBacktabPressed: root.move(-1)
                Keys.onReturnPressed: root.run()
                Keys.onEnterPressed: root.run()
                Keys.onEscapePressed: Panels.close()
                Keys.onPressed: event => {
                    if (event.modifiers & Qt.ControlModifier) {
                        if (event.key === Qt.Key_J || event.key === Qt.Key_N) { root.move(1); event.accepted = true; }
                        else if (event.key === Qt.Key_K || event.key === Qt.Key_P) { root.move(-1); event.accepted = true; }
                    }
                }

                Label {
                    visible: !input.text.length
                    text: "Search apps, or try  yt cats  ·  git"
                    color: Theme.muted
                    font.pixelSize: parent.font.pixelSize
                }
            }
        }
    }

    // ---- results
    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: field.bottom; topMargin: 8; leftMargin: 14; rightMargin: 14 }
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
            readonly property bool sel: index === root.selected
            readonly property bool hasIcon: iconImg.status === Image.Ready

            width: ListView.view.width
            height: root.rowH
            radius: 10
            color: sel ? Theme.surface2 : "transparent"

            // accent bar on the selected row
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
                            const i = row.modelData.icon;
                            if (!i) return "";
                            return i.charAt(0) === "/" ? "file://" + i : Quickshell.iconPath(i, true);
                        }
                    }
                    Glyph {
                        anchors.centerIn: parent
                        visible: !row.hasIcon
                        size: 18
                        color: row.sel ? Theme.accent : Theme.subtle
                        text: row.modelData.kind === "link" ? Icons.link
                            : row.modelData.kind === "action" ? Icons.search
                            : (row.modelData.name || "?").charAt(0).toUpperCase()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        text: row.modelData.name
                        color: row.sel ? Theme.fg : Theme.fgDim
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        visible: text !== ""
                        text: row.modelData.sub || ""
                        color: Theme.subtle
                        font.pixelSize: Config.font.size - 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Label {
                    visible: row.sel
                    text: "↵"
                    color: Theme.muted
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selected = row.index
                onClicked: { root.selected = row.index; root.run(); }
            }
        }
    }
}
