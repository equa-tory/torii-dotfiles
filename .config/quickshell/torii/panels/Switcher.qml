import qs
import qs.widgets
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Effects

// Wallpaper / theme switcher. Left/Right moves and previews on this monitor, Enter applies, Space adds / removes it from the random change
// (torii-theme restyles everything), Esc cancels. The folder is watched: drop an image in, it shows up.
Item {
    id: root

    property real maxWidth: 1000
    readonly property real thumbW: 188
    readonly property real thumbH: 106
    readonly property int count: folder.count
    readonly property string currentPath: list.currentItem ? list.currentItem.filePath : ""

    property string accentPreview: ""

    implicitWidth: Math.min(maxWidth, Math.max(520, count * (thumbW + 14) + 80))
    implicitHeight: 252

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
    function enterBar() {
        const i = modes.findIndex(m => m.key === curMode);
        barSel = i >= 0 ? i : 0;
        onBar = true;
    }
    function applyMode() {
        Quickshell.execDetached([Config.home + "/.config/torii/bin/torii-wallpaper", "shuffle", modes[barSel].key]);
    }

    function step(d) {
        if (onBar) { barSel = Math.max(0, Math.min(modes.length - 1, barSel + d)); return; }
        if (count === 0)
            return;
        moved = true;
        list.currentIndex = Math.max(0, Math.min(count - 1, list.currentIndex + d));
    }

    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onReturnPressed: { if (onBar) applyMode(); else confirm(); }
    Keys.onEnterPressed: { if (onBar) applyMode(); else confirm(); }
    Keys.onSpacePressed: { if (onBar) applyMode(); else toggleShuffle(); }
    Keys.onDownPressed: enterBar()
    Keys.onUpPressed: onBar = false
    Keys.onEscapePressed: { if (onBar) onBar = false; else Panels.close(); }

    FolderListModel {
        id: folder
        folder: "file://" + Config.expand(Config.wallpaper.dir)
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp", "*.mp4", "*.webm", "*.mkv", "*.mov", "*.gif"]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Name
        onStatusChanged: if (status === FolderListModel.Ready) { selectCurrent(); settle.restart(); }
        onCountChanged: if (status === FolderListModel.Ready) { if (list.currentIndex < 0) selectCurrent(); settle.restart(); }
    }

    // the folder fills in steps: once it has settled (and you have not moved yet) look again for the wallpaper that is active
    property bool moved: false
    Timer { id: settle; interval: 200; onTriggered: if (!root.moved) root.selectCurrent() }

    // start on the wallpaper that is active now
    function selectCurrent() {
        for (let i = 0; i < folder.count; i++) {
            if (folder.get(i, "filePath") === Theme.wallpaper) {
                list.currentIndex = i;
                return;
            }
        }
        list.currentIndex = folder.count > 0 ? 0 : -1;
    }

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
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 14 }
        height: root.thumbH * 1.2 + 16
        orientation: ListView.Horizontal
        spacing: 14
        model: folder
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
                    else { root.moved = true; list.currentIndex = cell.index; }
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
            color: Theme.fg
        }
        Label {
            text: (list.currentIndex + 1) + " / " + root.count
            color: Theme.muted
        }
        Label {
            text: list.currentItem && !root.inShuffle(list.currentItem.fileName) ? "Space: add to the random change" : "Space: leave the random change"
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
        visible: root.count === 0 && folder.status === FolderListModel.Ready
        text: "Drop images into " + Config.wallpaper.dir
        color: Theme.muted
    }
}
