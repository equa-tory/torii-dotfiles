pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

// The notification server (it replaces swaync). New notifications show for a few seconds in the notch and are kept
// in `history` (newest first, saved to notifications.json together with the do not disturb switch).
Singleton {
    id: root

    property bool dnd: false
    property var history: []              // [{ uid, app, summary, body, icon, time, urgent, actions }]
    property int unread: 0
    property var current: null            // the entry shown in the notch now
    property bool hovered: false          // the pointer is on the pop-up: it stays
    readonly property bool badgeVisible: unread > 0 && (!dnd || Config.notifications.badgeInDnd)

    property var queue: []
    property int seq: 0
    readonly property var live: ({})      // uid -> Notification object, while the sender still owns it
    readonly property string bin: Config.home + "/.config/torii/bin/"
    readonly property string stateFile: Config.stateDir + "/notifications.json"

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: false
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const uid = Date.now() * 1000 + (root.seq++ % 1000);
            const urgent = n.urgency === NotificationUrgency.Critical;
            let icon = n.image || n.appIcon || "";
            const entry = { uid: uid, app: n.appName || "", desktop: n.desktopEntry || "", summary: n.summary || "", body: n.body || "",
                            icon: icon, time: Date.now(), urgent: urgent,
                            actions: Array.from(n.actions).map(a => ({ id: a.identifier, text: a.text })) };
            root.live[uid] = n;
            n.closed.connect(() => { delete root.live[uid]; });
            root.history = [entry].concat(root.history).slice(0, 100);
            root.unread += 1;
            root.save();
            if (root.dnd && !urgent) return;
            if (entry.app !== "torii") Quickshell.execDetached([root.bin + "torii-sound", "notification"]);   // reminders play their own
            root.queue = root.queue.concat([entry]);
            if (root.current === null) root.next();
        }
    }

    function next() {
        if (queue.length === 0) { current = null; return; }
        current = queue[0];
        queue = queue.slice(1);
        hide.interval = Math.max(1, Config.notifications.popupSeconds) * 1000 * (current.urgent ? 2 : 1);
        hide.restart();
    }
    function closePopup() { hide.stop(); hovered = false; next(); }
    Timer {
        id: hide
        onTriggered: { if (root.hovered) hide.restart(); else root.next(); }
    }

    // the sender's default action, else bring its window forward
    function activate(entry) {
        const n = live[entry.uid];
        const act = n ? Array.from(n.actions).find(a => a.identifier === "default") : null;
        if (act) act.invoke();
        else focusApp(entry);
    }
    function invoke(entry, id) {
        const n = live[entry.uid];
        const act = n ? Array.from(n.actions).find(a => a.identifier === id) : null;
        if (act) act.invoke();
    }
    function focusApp(entry) {
        const key = (entry.desktop || entry.app || "").toLowerCase();
        if (key === "" || key === "torii") return;
        focusProc.key = key;
        focusProc.running = true;
    }
    Process {
        id: focusProc
        property string key: ""
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const hit = JSON.parse(text).find(c => c.class && (c.class.toLowerCase().indexOf(focusProc.key) >= 0 || focusProc.key.indexOf(c.class.toLowerCase()) >= 0));
                    if (hit) Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "address:' + hit.address + '" })']);
                } catch (e) {}
            }
        }
    }

    function dismiss(uid) {
        root.history = root.history.filter(e => e.uid !== uid);
        const n = live[uid];
        if (n) n.dismiss();
        if (current && current.uid === uid) closePopup();
        save();
    }
    function clear() {
        for (const uid in live) live[uid].dismiss();
        history = [];
        unread = 0;
        queue = [];
        if (current) closePopup();
        save();
    }
    function markRead() { if (unread !== 0) { unread = 0; save(); } }
    function toggleDnd() { dnd = !dnd; save(); }

    function ago(t) {
        const m = Math.floor((Date.now() - t) / 60000);
        if (m < 1) return "now";
        if (m < 60) return m + " min ago";
        const h = Math.floor(m / 60);
        return h < 24 ? h + " h ago" : Math.floor(h / 24) + " d ago";
    }

    // ---- persistence
    function save() { saveTimer.restart(); }
    Timer {
        id: saveTimer
        interval: 400
        onTriggered: file.setText(JSON.stringify({ dnd: root.dnd, unread: root.unread,
            history: root.history.map(e => Object.assign({}, e, { actions: [] })) }))
    }
    FileView {
        id: file
        path: root.stateFile
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.dnd = d.dnd === true;
                root.history = Array.isArray(d.history) ? d.history : [];
                root.unread = d.unread || 0;
            } catch (e) {}
        }
    }
}
