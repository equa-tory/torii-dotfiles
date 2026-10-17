pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import QtQuick

// What is switched on right now, read from small state files that the torii-* scripts write (watched, so a change
// shows up in the notch and in the launcher within a moment) and the do-not-disturb switch (kept by Notifs).
Singleton {
    id: root

    readonly property string dir: Config.stateDir

    property var reminders: []                                  // [{ id, start, due, msg }]
    property var automove: ({ enabled: false })
    property var night: ({ on: false, temp: 4000, mode: "gpu", auto: false, from: "20:00", to: "07:00" })
    property var recordingState: ({ on: false })
    property var sudoState: ({ on: false, until: 0 })
    property var hypr: ({ layout: "dwindle", gaps_in: 8, gaps_out: 20 })
    readonly property bool dnd: Notifs.dnd          // the notification server lives in Notifs

    property real now: Date.now()
    property string expanded: ""                                // key of the notch indicator that is open

    readonly property bool recording: recordingState.on === true
    readonly property bool sudoOn: sudoState.on === true && (sudoState.until === 0 || now / 1000 < sudoState.until)
    readonly property bool nightOn: night.on === true
    readonly property bool timed: reminders.length > 0 || (sudoState.on === true && sudoState.until > 0)

    Timer { interval: 1000; running: root.timed; repeat: true; triggeredOnStart: true; onTriggered: root.now = Date.now() }

    // safety net: a ring that reached 0 more than 2 s ago and is still listed means the system timer did not fire
    property double dueAsked: 0
    onNowChanged: {
        if (reminders.some(r => r.due < now / 1000 - 2) && now - dueAsked > 5000) {
            dueAsked = now;
            Quickshell.execDetached([Config.home + "/.config/torii/bin/torii-remind", "due"]);
        }
    }

    // expired reminders drop out of the list a moment before the script removes them
    function remaining(item) { return Math.max(0, item.due - now / 1000); }

    // files must exist for the watchers; the scripts overwrite them with real state
    Process {
        id: init
        running: true
        command: ["sh", "-c", 'mkdir -p "$1"; for f in reminders:[] automove:{} nightlight:{} recording:{} sudo:{} hypr-user:{}; do [ -e "$1/${f%%:*}.json" ] || echo "${f#*:}" > "$1/${f%%:*}.json"; done', "sh", root.dir]
        onExited: { for (const v of [fvRem, fvAuto, fvNight, fvRec, fvSudo, fvHypr]) v.reload(); }
    }

    function parse(text, fallback) { try { return JSON.parse(text); } catch (e) { return fallback; } }

    FileView { id: fvRem; path: root.dir + "/reminders.json"; watchChanges: true; printErrors: false
               onFileChanged: reload(); onLoaded: root.reminders = root.parse(text(), []) }
    FileView { id: fvAuto; path: root.dir + "/automove.json"; watchChanges: true; printErrors: false
               onFileChanged: reload(); onLoaded: root.automove = root.parse(text(), { enabled: false }) }
    FileView { id: fvNight; path: root.dir + "/nightlight.json"; watchChanges: true; printErrors: false
               onFileChanged: reload(); onLoaded: root.night = Object.assign({ on: false, temp: 4000, mode: "gpu", auto: false, from: "20:00", to: "07:00" }, root.parse(text(), {})) }
    FileView { id: fvRec; path: root.dir + "/recording.json"; watchChanges: true; printErrors: false
               onFileChanged: reload(); onLoaded: root.recordingState = root.parse(text(), { on: false }) }
    FileView { id: fvSudo; path: root.dir + "/sudo.json"; watchChanges: true; printErrors: false
               onFileChanged: reload(); onLoaded: root.sudoState = root.parse(text(), { on: false, until: 0 }) }
    FileView { id: fvHypr; path: root.dir + "/hypr-user.json"; watchChanges: true; printErrors: false
               onFileChanged: reload(); onLoaded: root.hypr = Object.assign({ layout: "dwindle", gaps_in: 8, gaps_out: 20 }, root.parse(text(), {})) }

}
