pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import QtQuick

// The media player that matters right now (MPRIS: players, browsers, anything that reports what it plays).
Singleton {
    id: root

    property var sticky: null                      // the last one that was playing

    function pick() {
        const all = Mpris.players.values;
        const playing = all.find(p => p.isPlaying);
        if (playing) return playing;
        if (sticky && all.indexOf(sticky) >= 0) return sticky;
        return all.find(p => (p.trackTitle || "") !== "") || null;
    }
    readonly property var player: pick()
    onPlayerChanged: if (player && player.isPlaying) sticky = player

    readonly property bool active: player !== null && (player.trackTitle || "") !== ""
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string title: player ? player.trackTitle || "" : ""
    readonly property string artist: player ? player.trackArtist || "" : ""
    readonly property string album: player ? player.trackAlbum || "" : ""
    readonly property string art: player ? player.trackArtUrl || "" : ""
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property real position: player && player.positionSupported ? player.position : 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : -1
    readonly property bool canSeek: player !== null && player.canSeek

    // is the player's own window the focused one? (then the notch does not need to tell you what plays)
    property string activeClass: ""
    readonly property string playerKey: player ? (player.desktopEntry || player.identity || "").toLowerCase() : ""
    readonly property bool playerFocused: activeClass !== "" && playerKey !== ""
        && (activeClass.indexOf(playerKey) >= 0 || playerKey.indexOf(activeClass) >= 0)
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindow") root.activeClass = (event.data.split(",")[0] || "").toLowerCase();
        }
    }
    Process {
        running: true
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { root.activeClass = (JSON.parse(text).class || "").toLowerCase(); } catch (e) {} } }
    }

    // the position only moves when asked
    Timer {
        interval: 1000
        running: root.playing
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged()
    }

    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying(); }
    function next() { if (player && player.canGoNext) player.next(); }
    function previous() { if (player && player.canGoPrevious) player.previous(); }
    function seekBy(seconds) {
        if (!player || !player.canSeek) return;
        player.position = Math.max(0, Math.min(length > 0 ? length : 1e9, player.position + seconds));
        player.positionChanged();
    }
    function seekTo(fraction) {
        if (!player || !player.canSeek || length <= 0) return;
        player.position = Math.max(0, Math.min(1, fraction)) * length;
        player.positionChanged();
    }

    // bring the player's window forward (the Hyprland client whose class matches the player)
    function focus() {
        if (!player) return;
        focusProc.key = (player.desktopEntry || player.identity || "").toLowerCase();
        if (focusProc.key !== "") focusProc.running = true;
    }
    Process {
        id: focusProc
        property string key: ""
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const k = focusProc.key;
                    const hit = JSON.parse(text).find(c => c.class && (c.class.toLowerCase().indexOf(k) >= 0 || k.indexOf(c.class.toLowerCase()) >= 0));
                    if (hit) Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "address:' + hit.address + '" })']);
                } catch (e) {}
            }
        }
    }

    function mmss(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
}
