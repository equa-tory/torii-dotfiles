import qs
import qs.services
import qs.widgets
import Quickshell
import QtQuick

// Things that are on right now (not background apps): reminders, muted mic, auto mover, recording, passwordless sudo,
// night light, do not disturb. Each is a small circle in the notch; click turns it off.
Row {
    id: root

    spacing: 8
    property real pad: 0                  // circles style: padding of each activity's own round backing
    property color backing: "transparent"
    readonly property int count: repeater.count

    readonly property string bin: Config.home + "/.config/torii/bin/"
    function run(args) { Quickshell.execDetached({ command: args, workingDirectory: Config.home }); }
    function clock(s) {
        s = Math.ceil(s);
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60;
        return (h > 0 ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(x).padStart(2, "0");
    }

    // only the identity of the entries lives here, so the list is rebuilt when something switches, not every second
    readonly property var entries: {
        if (Live.dnd) return [{ kind: "dnd", key: "dnd" }];       // do not disturb: nothing else is shown
        const out = [];
        for (const r of Live.reminders) out.push({ kind: "reminder", key: "r" + r.id, r: r });
        if (Media.active && (Live.expanded === "media" || !(Config.media.onlyWhenUnfocused && Media.playerFocused))) out.push({ kind: "media", key: "media" });
        if (Live.sudoOn) out.push({ kind: "sudo", key: "sudo" });
        if (Live.recording) out.push({ kind: "rec", key: "rec" });
        if (Audio.sourceMuted) out.push({ kind: "mic", key: "mic" });
        if (Live.automove.enabled === true) out.push({ kind: "automove", key: "automove" });
        if (Live.nightOn) out.push({ kind: "night", key: "night" });
        if (Live.dnd) out.push({ kind: "dnd", key: "dnd" });
        return out;
    }

    Component { id: mediaBody; MediaBody {} }

    Repeater {
        id: repeater
        model: root.entries

        delegate: Indicator {
            id: ind
            required property var modelData
            readonly property string kind: modelData.kind
            readonly property var r: modelData.r

            pad: root.pad
            backing: root.backing
            key: modelData.key
            glyph: kind === "reminder" ? Icons.timer : kind === "sudo" ? Icons.lock : kind === "rec" ? Icons.record
                 : kind === "media" ? Icons.music : kind === "mic" ? Icons.micOff : kind === "automove" ? Icons.folderMove : kind === "night" ? Icons.nightLight : Icons.bellOff
            tint: kind === "rec" || kind === "mic" ? Theme.red : kind === "sudo" || kind === "night" ? Theme.yellow : kind === "dnd" ? Theme.subtle : Theme.accent
            openable: kind === "reminder" || kind === "media"
            image: kind === "media" ? Media.art : ""
            content: kind === "media" ? mediaBody : null
            contentWidth: 430
            closable: kind === "reminder"
            remain: kind === "media" ? Media.progress : kind === "reminder" ? Math.min(1, Live.remaining(r) / Math.max(1, r.due - r.start))
                  : (kind === "sudo" && Live.sudoState.until > 0) ? Math.min(1, Math.max(0, Live.sudoState.until - Live.now / 1000) / Math.max(1, Live.sudoState.until - Live.sudoState.start))
                  : -1
            text: kind === "media" ? Media.title + (Media.artist ? "  ·  " + Media.artist : "")
                : kind === "mic" ? "Microphone muted · click to unmute"
                : kind === "rec" ? "Recording · click to stop"
                : kind === "automove" ? "Auto mover on · click to turn off"
                : kind === "night" ? "Night light " + Live.night.temp + " K · click to turn off"
                : kind === "dnd" ? "Do not disturb · click to turn off"
                : kind === "sudo" ? (Live.sudoState.until > 0 ? "Passwordless sudo · " + root.clock(Math.max(0, Live.sudoState.until - Live.now / 1000)) + " left · click to turn off"
                                                              : "Passwordless sudo until reboot · click to turn off")
                : "Reminder · click for details"
            detail: kind === "reminder" ? root.clock(Live.remaining(r)) + "  ·  " + (r.msg || "Reminder") : ""

            onActivated: {
                if (kind === "mic") Audio.toggleSourceMute();
                else if (kind === "rec") root.run([root.bin + "torii-capture", "record"]);
                else if (kind === "automove") root.run([root.bin + "torii-automove", "off"]);
                else if (kind === "night") root.run([root.bin + "torii-nightlight", "off"]);
                else if (kind === "dnd") Notifs.toggleDnd();
                else if (kind === "sudo") root.run(["sh", "-c", "echo | " + root.bin + "torii-sudo off"]);
            }
            onClosed: { Live.expanded = ""; root.run([root.bin + "torii-remind", "cancel", r.id]); }
        }
    }
}
