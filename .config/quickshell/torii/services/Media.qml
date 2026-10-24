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

    // a clip of a couple of seconds (a page looping a sound effect, an alert chirp) is not media worth an activity
    readonly property bool tiny: player !== null && player.lengthSupported && player.length > 0 && player.length < 3
    readonly property bool active: player !== null && (player.trackTitle || "") !== "" && !tiny
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string title: player ? player.trackTitle || "" : ""
    readonly property string artist: player ? player.trackArtist || "" : ""
    readonly property string album: player ? player.trackAlbum || "" : ""
    readonly property string art: player ? player.trackArtUrl || "" : ""
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property real position: player && player.positionSupported ? player.position : 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : -1
    readonly property bool canSeek: player !== null && player.canSeek

    // every player that is playing something right now gets its own activity (two browsers, a browser and mpv...);
    // when none plays, the last one stays (paused) as before. Tabs of one browser share a single player, so they cannot be split.
    function isMedia(p) {
        return p !== null && (p.trackTitle || "") !== "" && !(p.lengthSupported && p.length > 0 && p.length < 3);
    }
    readonly property var list: {
        const out = Mpris.players.values.filter(p => p.isPlaying && isMedia(p));
        if (out.length === 0 && active) out.push(player);
        return out;
    }
    function forKey(key) {            // "media" = the first one, "media:<n>" the others
        const n = key === "media" ? 0 : parseInt((key || "").split(":")[1]);
        return list[n] || player;
    }
    function playerKeyOf(p) { return p ? (p.desktopEntry || p.identity || "").toLowerCase() : ""; }
    function focusedOn(p) {
        const k = playerKeyOf(p);
        return activeClass !== "" && k !== "" && (activeClass.indexOf(k) >= 0 || k.indexOf(activeClass) >= 0);
    }

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
        running: root.list.length > 0
        repeat: true
        onTriggered: { for (const p of root.list) p.positionChanged(); }
    }

    function toggle(p) { p = p || player; if (p && p.canTogglePlaying) p.togglePlaying(); }
    function next(p) { p = p || player; if (p && p.canGoNext) p.next(); }
    function previous(p) { p = p || player; if (p && p.canGoPrevious) p.previous(); }
    function seekBy(seconds, p) {
        p = p || player;
        if (!p || !p.canSeek) return;
        p.position = Math.max(0, Math.min(p.lengthSupported && p.length > 0 ? p.length : 1e9, p.position + seconds));
        p.positionChanged();
    }
    function seekTo(fraction, p) {
        p = p || player;
        if (!p || !p.canSeek || !p.lengthSupported || p.length <= 0) return;
        p.position = Math.max(0, Math.min(1, fraction)) * p.length;
        p.positionChanged();
    }

    // bring the player's window forward (the Hyprland client whose class matches the player)
    function focus(p) {
        p = p || player;
        if (!p) return;
        focusProc.key = playerKeyOf(p);
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
