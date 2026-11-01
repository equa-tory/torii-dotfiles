import qs
import qs.widgets
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects

// Wallpaper / theme switcher. Left/Right moves, PageUp/PageDown jumps a visible page, Enter applies, Space toggles random change
// (torii-theme restyles everything), Esc cancels. The folder is watched: drop an image in, it shows up.
Item {
    id: root

    property real maxWidth: 1000
    readonly property real thumbW: 188
    readonly property real thumbH: 106
    readonly property int count: pictures.count
    readonly property string currentPath: list.currentItem ? list.currentItem.filePath : ""

    property string accentPreview: ""

    implicitWidth: maxWidth
    implicitHeight: 300

    opacity: 0
    focus: true
    Component.onCompleted: { opacity = 1; forceActiveFocus(); }
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    function confirm() {
        if (currentPath === "")
            return;
        const path = currentPath;
        Panels.pendingWallpaper = path;
        Quickshell.execDetached([Config.home + "/.config/torii/bin/torii-theme", "set", path]);
        Panels.close();
    }

    // Space: this wallpaper joins / leaves the random change (config.json wallpaper.noShuffle)
    readonly property var skipped: Config.wallpaper.noShuffle || []
    function inShuffle(name) { return skipped.indexOf(name) < 0; }
    function toggleShuffle() {
        if (!list.currentItem) return;
        Quickshell.execDetached([Config.home + "/.config/torii/bin/torii-wallpaper", "skip", list.currentItem.fileName]);
    }

    function toggleFolderShuffle() {
        if (!count) return;
        const names = [];
        for (let i = 0; i < count; i++) names.push(pictures.get(i).fileName);
        const enable = names.some(name => !inShuffle(name));
        const updated = skipped.filter(name => names.indexOf(name) < 0);
        if (!enable) names.forEach(name => { if (updated.indexOf(name) < 0) updated.push(name); });
        Quickshell.execDetached([Config.home + "/.config/torii/bin/torii-config", "set", "wallpaper.noShuffle", JSON.stringify(updated)]);
    }
    property string dragFolder: ""
    property string dropFolder: ""
    function dragOver(position) {
        for (let i = 0; i < headerItems.length; i++) {
            const item = headerButtons.itemAt(i);
            if (headerItems[i].kind === "folder" && position >= item.x && position <= item.x + item.width) {
                dropFolder = headerItems[i].name;
                return;
            }
        }
    }
    function finishFolderDrag() {
        if (dragFolder && dropFolder && dragFolder !== dropFolder) {
            const ordered = albums.slice();
            const target = ordered.indexOf(dropFolder);
            ordered.splice(ordered.indexOf(dragFolder), 1);
            ordered.splice(target, 0, dragFolder);
            albums = ordered;
            request("reorder", ordered);
        }
        dragFolder = ""; dropFolder = "";
    }

    // the pictures for the video wallpapers (one frame each) are made on first open
    property bool stillsReady: false
    Process {
        running: true
        command: [Config.home + "/.config/torii/bin/torii-theme", "stills"]
        onExited: root.stillsReady = true
    }

    // Down: the row of random-change choices at the bottom (Left/Right choose, Enter or Space applies, Up goes back to the pictures)
    readonly property var modes: [{ key: "off", label: "Off" }, { key: "5", label: "5 min" }, { key: "30", label: "30 min" }, { key: "60", label: "1 hour" }, { key: "login", label: "On login" }]
    readonly property string curMode: Config.wallpaper.shuffle || "off"
    property bool onBar: false
    property int barSel: 0
    property bool onHeader: false
    property int headerSel: 0
    readonly property var headerItems: {
        const actions = [{kind: "new", text: "New folder (n)"},
                         {kind: "edit", text: membershipMode ? "Done (esc)" : "Edit (e)"}];
        if (customAlbum && !membershipMode) actions.push({kind: "delete", text: deleting ? "Confirm delete (d)" : "Delete folder (d)"});
        if (deleting) actions.push({kind: "cancel", text: "Cancel"});
        return actions.concat(albums.map(name => ({kind: "folder", name: name,
            text: (membershipMode && name !== "All" && name !== "Animated" ? (customFolders.indexOf(name) < 9 ? String(customFolders.indexOf(name) + 1) + " " : "")
                + (memberships.indexOf(name) >= 0 ? "✓ " : "+ ") : "") + name})));
    }
    function keepHeaderVisible() {
        const chip = headerButtons.itemAt(headerSel);
        if (!chip) return;
        if (chip.x < headerStrip.contentX) headerStrip.contentX = chip.x;
        else if (chip.x + chip.width > headerStrip.contentX + headerStrip.width)
            headerStrip.contentX = chip.x + chip.width - headerStrip.width;
    }
    onHeaderSelChanged: Qt.callLater(keepHeaderVisible)
    onHeaderItemsChanged: { headerSel = Math.min(headerSel, headerItems.length - 1); Qt.callLater(keepHeaderVisible); }
    function enterHeader() {
        onBar = false; onHeader = true;
        const index = headerItems.findIndex(item => item.kind === "folder" && item.name === album);
        headerSel = Math.max(0, index);
        Qt.callLater(keepHeaderVisible);
    }
    function toggleMembership() {
        membershipMode = !membershipMode; deleting = false;
        onBar = false; onHeader = true;
        headerSel = membershipMode ? Math.max(0, headerItems.findIndex(item => item.kind === "folder" && item.name !== "All" && item.name !== "Animated")) : 1;
        request("list");
    }
    function activateHeader() {
        const item = headerItems[headerSel];
        if (!item) return;
        if (item.kind === "new") startCreate();
        else if (item.kind === "edit") toggleMembership();
        else if (item.kind === "delete") deleteAlbum();
        else if (item.kind === "cancel") deleting = false;
        else selectAlbum(item.name);
    }
    function activate() {
        if (onHeader) activateHeader();
        else if (onBar) applyMode();
        else confirm();
    }
    function enterBar() {
        const i = modes.findIndex(m => m.key === curMode);
        barSel = i >= 0 ? i : 0;
        onBar = true; onHeader = false;
    }
    function applyMode() {
        Quickshell.execDetached([Config.home + "/.config/torii/bin/torii-wallpaper", "shuffle", modes[barSel].key]);
    }

    function step(d) {
        if (onHeader) { headerSel = Math.max(0, Math.min(headerItems.length - 1, headerSel + d)); return; }
        if (onBar) { barSel = Math.max(0, Math.min(modes.length - 1, barSel + d)); return; }
        if (count === 0)
            return;
        list.currentIndex = Math.max(0, Math.min(count - 1, list.currentIndex + d));
    }

    function page(d) {
        onBar = false; onHeader = false;
        step(d * Math.max(1, Math.floor((list.width + list.spacing) / (thumbW + list.spacing))));
    }

    Keys.onTabPressed: { membershipMode = false; selectAlbum(albums[(albums.indexOf(album) + 1) % albums.length]); }
    Keys.onBacktabPressed: { membershipMode = false; selectAlbum(albums[(albums.indexOf(album) + albums.length - 1) % albums.length]); }
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onPressed: event => {
        if (membershipMode && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            const name = customFolders[event.key - Qt.Key_1];
            if (name && currentPath !== "") request("toggle", [name, currentPath]);
            event.accepted = true;
        }
        else if (event.key === Qt.Key_N) { startCreate(); event.accepted = true; }
        else if (event.key === Qt.Key_D) { if (customAlbum && !membershipMode) deleteAlbum(); event.accepted = true; }
        else if (event.key === Qt.Key_E) { toggleMembership(); event.accepted = true; }
        else if (event.key === Qt.Key_A) { toggleFolderShuffle(); event.accepted = true; }
        else if (event.key === Qt.Key_Delete && !onHeader && !onBar && customAlbum && currentPath !== "") { request("remove", [album, currentPath]); event.accepted = true; }
        else if (event.key === Qt.Key_PageDown) { page(-1); event.accepted = true; }
        else if (event.key === Qt.Key_PageUp) { page(1); event.accepted = true; }
    }
    Keys.onReturnPressed: activate()
    Keys.onEnterPressed: activate()
    Keys.onSpacePressed: { if (onHeader) activateHeader(); else if (onBar) applyMode(); else toggleShuffle(); }
    Keys.onDownPressed: { if (onHeader) onHeader = false; else enterBar(); }
    Keys.onUpPressed: { if (onBar) onBar = false; else enterHeader(); }
    Keys.onEscapePressed: { if (membershipMode) membershipMode = false; else if (deleting) deleting = false; else if (onHeader) onHeader = false; else if (onBar) onBar = false; else Panels.close(); }

    property string album: "All"
    property var albums: ["All", "Animated"]
    readonly property var customFolders: albums.filter(name => name !== "All" && name !== "Animated")
    property var memberships: []
    property bool membershipMode: false
    property bool creating: false
    property bool deleting: false
    property string message: ""
    property string previousItems: ""
    property var requests: []
    readonly property bool customAlbum: album !== "All" && album !== "Animated"

    ListModel { id: pictures }

    function request(action, args) {
        if (action === "list" && (inventory.running || requests.length > 0)) return;
        requests.push({action: action, args: args || []});
        nextRequest();
    }
    function nextRequest() {
        if (inventory.running || requests.length === 0) return;
        const req = requests.shift();
        inventory.targetFolder = album;
        inventory.action = req.action;
        inventory.command = [Config.home + "/.config/torii/bin/torii-wallpaper-folders",
            "--folder=" + album, "--current=" + currentPath, req.action, "--"].concat(req.args);
        inventory.running = true;
    }
    function selectAlbum(name) {
        deleting = false;
        if (membershipMode) {
            if (name !== "All" && name !== "Animated" && currentPath !== "")
                request("toggle", [name, currentPath]);
            return;
        }
        album = name;
        request("list");
    }
    function newAlbum() {
        const name = folderName.text.trim();
        if (name === "") return;
        request("create", [name]);
        creating = false; onHeader = true;
        root.forceActiveFocus();
    }
    function startCreate() {
        creating = true; deleting = false; onBar = false; onHeader = true; folderName.text = "";
        folderName.forceActiveFocus();
    }
    function deleteAlbum() {
        if (!customAlbum) return;
        if (!deleting) { deleting = true; return; }
        const name = album;
        album = "All"; deleting = false;
        request("delete", [name]);
    }

    Process {
        id: inventory
        property string targetFolder: ""
        property string action: "list"
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (!root.dragFolder) root.albums = d.folders;
                    if (inventory.action !== "list" || d.error) root.message = d.error || "";
                    if (inventory.targetFolder === root.album) {
                        root.album = d.folder;
                        root.memberships = d.memberships;
                        const encoded = JSON.stringify(d.items);
                        if (encoded !== root.previousItems) {
                            const keep = root.currentPath;
                            pictures.clear();
                            d.items.forEach(item => pictures.append(item));
                            root.previousItems = encoded;
                            let idx = d.items.findIndex(item => item.filePath === keep);
                            if (idx < 0) idx = d.items.findIndex(item => item.filePath === Theme.wallpaper);
                            list.currentIndex = idx >= 0 ? idx : (pictures.count > 0 ? 0 : -1);
                        }
                    }
                } catch (e) { root.message = "Could not read wallpaper folders"; }
            }
        }
        onExited: Qt.callLater(() => {
            if (root.requests.length > 0) root.nextRequest();
            else if (targetFolder !== root.album) root.request("list");
        })
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.request("list") }


    Flickable {
        id: headerStrip
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20; topMargin: 12 }
        height: 32; clip: true; visible: !root.creating
        contentWidth: folderRow.width; contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        Row {
            id: folderRow
            spacing: 8
            Repeater {
                id: headerButtons
                model: root.headerItems
                WallpaperFolderButton {
                    required property var modelData
                    required property int index
                    text: modelData.text
                    draggable: modelData.kind === "folder"
                    dropTarget: root.dropFolder === modelData.name && root.dragFolder !== ""
                    onDragStarted: { root.dragFolder = modelData.name; root.dropFolder = modelData.name; }
                    onDragMoved: position => root.dragOver(mapToItem(folderRow, position, 0).x)
                    onDragFinished: root.finishFolderDrag()
                    keyboardSelected: root.onHeader && root.headerSel === index
                    chosen: modelData.kind === "edit" ? root.membershipMode : modelData.kind === "folder"
                        && (root.membershipMode ? root.memberships.indexOf(modelData.name) >= 0 : root.album === modelData.name)
                    opacity: root.membershipMode && modelData.kind === "folder"
                        && (modelData.name === "All" || modelData.name === "Animated") ? 0.4 : 1
                    onClicked: { root.onHeader = true; root.onBar = false; root.headerSel = index; root.forceActiveFocus(); root.activateHeader(); }
                }
            }
        }
    }
    Row {
        x: 20; y: 12; spacing: 8; visible: root.creating
        Rectangle {
            width: 260; height: 28; radius: 8; color: Theme.surface
            TextInput {
                id: folderName
                anchors { fill: parent; margins: 5 }
                color: Theme.fg; font.family: Config.font.family; font.pixelSize: Config.font.size
                selectByMouse: true; clip: true
                Keys.onReturnPressed: root.newAlbum()
                Keys.onEnterPressed: root.newAlbum()
                Keys.onEscapePressed: { root.creating = false; root.forceActiveFocus(); }
            }
        }
        WallpaperFolderButton { text: "Create"; onClicked: root.newAlbum() }
        WallpaperFolderButton { text: "Cancel"; onClicked: { root.creating = false; root.forceActiveFocus(); } }
    }
    Label { x: 20; y: 45; text: root.message; color: Theme.red; visible: text !== ""; width: parent.width - 40; elide: Text.ElideRight }

    // live preview, debounced so holding an arrow key stays smooth
    Timer {
        id: previewTimer
        interval: 90
        onTriggered: {
            Panels.previewWallpaper = root.currentPath === Theme.wallpaper ? "" : root.currentPath;
            palette.fetch(root.currentPath);
        }
    }

    // the accent this wallpaper would produce (torii-theme palette; cached by image hash, so it is fast)
    Process {
        id: palette
        property string wanted: ""
        property string loading: ""
        function fetch(path) {
            wanted = path;
            if (running || path === "")
                return;
            loading = path;
            command = [Config.home + "/.config/torii/bin/torii-theme", "palette", path];
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (palette.loading === palette.wanted)
                        root.accentPreview = JSON.parse(text).accent;
                } catch (e) {}
                if (palette.wanted !== palette.loading)
                    palette.fetch(palette.wanted);
            }
        }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 60 }
        height: root.thumbH * 1.2 + 16
        orientation: ListView.Horizontal
        spacing: 14
        model: pictures
        currentIndex: -1
        clip: true
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - root.thumbW) / 2
        preferredHighlightEnd: (width + root.thumbW) / 2
        highlightMoveDuration: 220
        highlightMoveVelocity: -1
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: previewTimer.restart()

        delegate: Item {
            id: cell
            required property int index
            required property string filePath
            required property string fileName
            readonly property bool selected: ListView.isCurrentItem

            width: root.thumbW
            height: list.height

            Rectangle {
                id: frame
                anchors.centerIn: parent
                width: root.thumbW
                height: root.thumbH
                radius: 12
                color: Theme.surface
                scale: cell.selected ? 1.14 : 0.94
                opacity: cell.selected ? 1 : 0.55
                border.width: cell.selected ? 2 : 0
                border.color: root.accentPreview !== "" ? root.accentPreview : Theme.accent

                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Image {
                    id: img
                    anchors.fill: parent
                    anchors.margins: frame.border.width
                    source: (Config.isVideo(cell.filePath) && !root.stillsReady) ? "" : "file://" + Config.still(cell.filePath)
                    sourceSize: Qt.size(root.thumbW * 2, root.thumbH * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    visible: false
                }
                // round the picture's corners to match the frame
                Rectangle {
                    id: round
                    anchors.fill: img
                    radius: frame.radius - frame.border.width
                    visible: false
                    layer.enabled: true
                }
                MultiEffect {
                    anchors.fill: img
                    source: img
                    maskEnabled: true
                    maskSource: round
                }
                // small markers: a video, and "not in the random change"
                Row {
                    anchors { left: parent.left; top: parent.top; leftMargin: 8; topMargin: 8 }
                    spacing: 4
                    Rectangle {
                        visible: Config.isVideo(cell.filePath)
                        height: 16; width: vlabel.implicitWidth + 10; radius: 8
                        color: Qt.rgba(0, 0, 0, 0.6)
                        Label { id: vlabel; anchors.centerIn: parent; text: "▶ video"; color: "white"; font.pixelSize: 10 }
                    }
                    Rectangle {
                        visible: !root.inShuffle(cell.fileName)
                        height: 16; width: slabel.implicitWidth + 10; radius: 8
                        color: Qt.rgba(0, 0, 0, 0.6)
                        Label { id: slabel; anchors.centerIn: parent; text: "not shuffled"; color: "white"; font.pixelSize: 10 }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (cell.selected) root.confirm();
                    else { list.currentIndex = cell.index; }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => root.step(wheel.angleDelta.y + wheel.angleDelta.x < 0 ? 1 : -1)
        }
    }

    // caption: name · n/N · accent swatch
    Row {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 48 }
        spacing: 10
        visible: root.count > 0

        Rectangle {
            width: 10
            height: 10
            radius: 5
            anchors.verticalCenter: parent.verticalCenter
            color: root.accentPreview !== "" ? root.accentPreview : Theme.accent
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        Label {
            text: list.currentItem ? list.currentItem.fileName : ""
            width: Math.min(implicitWidth, Math.max(120, root.width - 420))
            elide: Text.ElideMiddle
            color: Theme.fg
        }
        Label {
            text: (list.currentIndex + 1) + " / " + root.count
            color: Theme.muted
        }
        Label {
            text: list.currentItem && !root.inShuffle(list.currentItem.fileName) ? "Space: add picture · A: toggle folder shuffle" : "Space: skip picture · A: toggle folder shuffle"
            color: Theme.muted
        }
    }

    // random change of the wallpaper: the active choice has a dot, the key-selected one an outline
    Row {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 10 }
        spacing: 6
        Label { anchors.verticalCenter: parent.verticalCenter; text: root.onBar ? "Random change" : "↓ Random change"; color: Theme.muted; rightPadding: 6 }
        Repeater {
            model: root.modes
            Rectangle {
                required property var modelData
                required property int index
                readonly property bool active: modelData.key === root.curMode
                width: chipLabel.implicitWidth + 22; height: 26; radius: 8
                color: active ? Theme.accent : Theme.surface
                border.width: root.onBar && index === root.barSel ? 1 : 0
                border.color: Theme.fg
                Label { id: chipLabel; anchors.centerIn: parent; text: modelData.label; color: parent.active ? Theme.accentFg : Theme.fgDim; font.pixelSize: Config.font.size - 1 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.barSel = index; root.applyMode(); } }
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: root.count === 0 && !inventory.running
        text: root.customAlbum ? "Empty folder · choose a picture in All, then E to edit membership" : "No wallpapers in " + root.album
        color: Theme.muted
    }
}
