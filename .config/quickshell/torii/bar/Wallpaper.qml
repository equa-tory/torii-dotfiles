import qs
import Quickshell
import Quickshell.Wayland
import QtQuick

// The shell draws the wallpaper itself (crossfade). One layer per monitor.
PanelWindow {
    id: win

    readonly property bool previewing: Panels.previewWallpaper !== "" && Panels.panelScreen === screen.name
    readonly property string path: previewing ? Panels.previewWallpaper
                                 : (Panels.pendingWallpaper !== "" ? Panels.pendingWallpaper : Theme.wallpaper)

    property Image top: null          // the image currently fully shown
    property Image pending: null      // the image being faded in

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "torii-wallpaper"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.bg

    onPathChanged: show(path)
    Component.onCompleted: show(path)

    function show(p) {
        if (p === "")
            return;
        const src = "file://" + p;
        if (top && top.source == src && !pending)
            return;
        const next = top === a ? b : a;
        pending = next;
        next.opacity = 0;
        next.source = src;
        if (next.status === Image.Ready)
            reveal();
    }

    function reveal() {
        if (!pending)
            return;
        pending.z = 2;
        if (top)
            top.z = 1;
        fade.target = pending;
        fade.duration = top ? Config.wallpaper.transitionMs : 150;
        fade.restart();
    }

    NumberAnimation {
        id: fade
        property: "opacity"
        from: 0
        to: 1
        easing.type: Easing.InOutQuad
        onFinished: {
            const old = win.top;
            win.top = win.pending;
            win.pending = null;
            if (old)
                old.opacity = 0;
        }
    }

    Item {
        anchors.fill: parent

        Image {
            id: a
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: Qt.size(win.width, win.height)
            onStatusChanged: if (status === Image.Ready && win.pending === this) win.reveal()
        }
        Image {
            id: b
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: Qt.size(win.width, win.height)
            onStatusChanged: if (status === Image.Ready && win.pending === this) win.reveal()
        }
    }
}
