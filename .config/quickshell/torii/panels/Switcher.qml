import qs
import qs.widgets
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Effects

// Wallpaper / theme switcher. Left/Right moves and previews on this monitor, Space/Enter applies
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
    implicitHeight: 214

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

    function step(d) {
        if (count === 0)
            return;
        list.currentIndex = Math.max(0, Math.min(count - 1, list.currentIndex + d));
    }

    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onReturnPressed: confirm()
    Keys.onEnterPressed: confirm()
    Keys.onSpacePressed: confirm()
    Keys.onEscapePressed: Panels.close()

    FolderListModel {
        id: folder
        folder: "file://" + Config.expand(Config.wallpaper.dir)
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Name
        onStatusChanged: if (status === FolderListModel.Ready) selectCurrent()
        onCountChanged: if (status === FolderListModel.Ready && list.currentIndex < 0) selectCurrent()
    }

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
                    source: "file://" + cell.filePath
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
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (cell.selected) root.confirm();
                    else list.currentIndex = cell.index;
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
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 14 }
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
    }

    Label {
        anchors.centerIn: parent
        visible: root.count === 0 && folder.status === FolderListModel.Ready
        text: "Drop images into " + Config.wallpaper.dir
        color: Theme.muted
    }
}
