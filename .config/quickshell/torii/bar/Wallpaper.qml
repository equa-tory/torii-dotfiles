import qs
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtMultimedia

// The shell draws the wallpaper itself (crossfade). One layer per monitor.
PanelWindow {
    id: win

    readonly property bool previewing: Panels.previewWallpaper !== "" && Panels.panelScreen === screen.name
    readonly property string path: previewing ? Panels.previewWallpaper
                                 : (Panels.pendingWallpaper !== "" ? Panels.pendingWallpaper : Theme.wallpaper)

    // a video wallpaper plays on top of its still frame (which is what the crossfade and the previews show)
    readonly property bool isVideo: Config.isVideo(path)
    readonly property var mon: Hyprland.monitorFor(screen)
    readonly property bool covered: mon && mon.activeWorkspace && mon.activeWorkspace.lastIpcObject ? mon.activeWorkspace.lastIpcObject.hasfullscreen === true : false
    readonly property bool playVideo: isVideo && !previewing

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
        const src = "file://" + Config.still(p);
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

    // the clip: starts when it is the wallpaper (not a preview), fades in over the still, stops while a fullscreen window hides it
    MediaPlayer {
        id: player
        source: win.playVideo ? "file://" + win.path : ""
        loops: MediaPlayer.Infinite
        videoOutput: vout
        onSourceChanged: if (source.toString() !== "") play()
    }
    Timer {
        // a fullscreen window over the wallpaper: stop decoding; back to play when it goes
        interval: 300; running: win.playVideo; repeat: true
        onTriggered: {
            if (win.covered && player.playbackState === MediaPlayer.PlayingState) player.pause();
            else if (!win.covered && player.playbackState === MediaPlayer.PausedState) player.play();
        }
    }

    Item {
        anchors.fill: parent

        VideoOutput {
            id: vout
            anchors.fill: parent
            z: 5
            fillMode: VideoOutput.PreserveAspectCrop
            opacity: win.playVideo && player.position > 150 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 500 } }
        }

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
