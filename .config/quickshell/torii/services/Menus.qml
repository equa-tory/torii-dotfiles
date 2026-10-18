pragma Singleton
import qs
import qs.widgets
import "../widgets/fuzzy.js" as Fuzzy
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Networking
import QtQuick

// The launcher's menu tree. A node is a plain object:
//   { id, name, sub, glyph | icon, badge, keywords,
//     children: [nodes] | () => [nodes]      Right/Enter opens it
//     run: () => void                        Enter runs it (Right too, when there are no children)
//     keep: true                             launcher stays open after run
//     flat: true                             its children are searched as if they were at the top level }
// ~/.config/torii/menu.json sets the order of the menus (and of any submenu) and can hide entries.
Singleton {
    id: root

    property int rev: 0                    // bumped when the lists need to be rebuilt
    property var prompt: null              // { label, secret, submit(text) } while the launcher asks for text
    property string notice: ""             // short message under the field
    property var orderCfg: ({ order: [], hidden: [], submenus: {} })

    readonly property string home: Config.home
    function bump() { rev++; }

    FileView {
        path: root.home + "/.config/torii/menu.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.orderCfg = Object.assign({ order: [], hidden: [], submenus: {} }, JSON.parse(text())); root.bump(); }
            catch (e) { console.warn("menu.json: invalid JSON"); }
        }
    }

    Connections { target: Net; function onWifiNetworksChanged() { root.bump(); } function onIpChanged() { root.bump(); } function onScanningChanged() { root.bump(); } }
    Connections { target: Bt; function onDevicesChanged() { root.bump(); } function onPoweredChanged() { root.bump(); } function onScanningChanged() { root.bump(); } }
    Connections { target: Audio; function onSinksChanged() { root.bump(); } function onSourcesChanged() { root.bump(); } function onSourceMutedChanged() { root.bump(); } }

    Timer { id: noticeTimer; interval: 3500; onTriggered: root.notice = "" }
    function say(text) { notice = text; noticeTimer.restart(); }

    function ask(label, secret, submit) { prompt = { label: label, secret: secret, submit: submit }; }
    function endPrompt() { prompt = null; }

    // ---- helpers
    function sh(args) { Quickshell.execDetached({ command: args, workingDirectory: home }); }
    function app(args) { sh(Apps.wrap(args)); }
    function edit(path) { app(["kitty", "sh", "-c", 'exec "${EDITOR:-nvim}" "$1"', "sh", path]); }
    function bin(name) { return home + "/.config/torii/bin/" + name; }
    function later(fetch, ms) { fetchTimer.target = fetch; fetchTimer.interval = ms || 400; fetchTimer.restart(); }
    Timer { id: fetchTimer; property var target; onTriggered: if (target) { target.refresh(); } }

    // ---- state read from helper scripts
    JsonFetch { id: fBrowser;  command: [root.bin("torii-default"), "list", "browser"];  onDataChanged: root.bump() }
    JsonFetch { id: fFiles;    command: [root.bin("torii-default"), "list", "files"];    onDataChanged: root.bump() }
    JsonFetch { id: fTerminal; command: [root.bin("torii-default"), "list", "terminal"]; onDataChanged: root.bump() }
    JsonFetch { id: fEditor;   command: [root.bin("torii-default"), "list", "editor"];   onDataChanged: root.bump() }
    JsonFetch { id: fEmoji;    command: [root.bin("torii-emoji"), "list"];
                onDataChanged: { root.emojiNodes = (data || []).map(e => ({ id: "e:" + e.c, name: e.n, sub: e.g, glyph: e.c, run: () => app([root.bin("torii-emoji"), "copy", e.c]) }));
                    root.bump(); } }
    JsonFetch { id: fProcs;    command: [root.bin("torii-sys"), "procs"];             onDataChanged: root.bump() }
    JsonFetch { id: fRules;    command: [root.bin("torii-rules"), "list"];            onDataChanged: root.bump() }
    JsonFetch { id: fSyncStatus; command: [root.bin("torii-sync"), "status"];          onDataChanged: root.bump() }
    JsonFetch { id: fSyncApps; command: [root.bin("torii-sync"), "apps"];              onDataChanged: root.bump() }
    JsonFetch { id: fSpecials; command: [root.bin("torii-rules"), "specials"];        onDataChanged: root.bump() }
    JsonFetch { id: fWins;     command: [root.bin("torii-rules"), "windows"];         onDataChanged: root.bump() }
    JsonFetch { id: fSounds;   command: [root.bin("torii-sound"), "list"];             onDataChanged: root.bump() }
    JsonFetch { id: fGit;      command: [root.bin("torii-install"), "git-status"];        onDataChanged: root.bump() }
    JsonFetch { id: fWeb;      command: [root.bin("torii-apps"), "webapp", "list"];       onDataChanged: root.bump() }
    JsonFetch { id: fTui;      command: [root.bin("torii-apps"), "tui", "list"];          onDataChanged: root.bump() }
    JsonFetch { id: fLearnHypr; command: [root.bin("torii-learn"), "list", "hypr"];       onDataChanged: root.bump() }
    JsonFetch { id: fLearnTmux; command: [root.bin("torii-learn"), "list", "tmux"];       onDataChanged: root.bump() }
    JsonFetch { id: fLearnNvim; command: [root.bin("torii-learn"), "list", "nvim"];       onDataChanged: root.bump() }
    JsonFetch { id: fNotes;    command: [root.bin("torii-learn"), "files"];               onDataChanged: root.bump() }
    JsonFetch { id: fHypr;     command: [root.bin("torii-hypr"), "status"];                onDataChanged: root.bump() }
    JsonFetch { id: fCalSync;  command: [root.bin("torii-calendar"), "autosync", "status"];  onDataChanged: root.bump() }
    JsonFetch { id: fClean;    command: [root.bin("torii-clean"), "list"];                 onDataChanged: root.bump() }
    JsonFetch { id: fBig;      command: [root.bin("torii-clean"), "big", "100"];           onDataChanged: root.bump() }
    JsonFetch { id: fMons;     command: [root.bin("torii-hypr"), "monitors"];              onDataChanged: root.bump() }
    JsonFetch { id: fTrans;    command: [root.bin("torii-transcode"), "list"];            onDataChanged: root.bump() }
    property var emojiNodes: []
    readonly property var allFetch: [fBrowser, fFiles, fTerminal, fEditor, fEmoji, fProcs, fSounds, fRules, fWins, fSpecials, fSyncApps, fSyncStatus, fTrans, fHypr, fMons, fClean, fBig, fCalSync, fGit, fWeb, fTui, fLearnHypr, fLearnTmux, fLearnNvim, fNotes]
    Connections { target: Theme; function onModeChanged() { root.bump(); } }
    // switches kept in config.json (the badge of a toggle must change at once, not when the menu is reopened)
    Connections { target: Config.capture; function onFreezeChanged() { root.bump(); } }
    Connections { target: Config.launcher; function onSearchHiddenChanged() { root.bump(); } }
    readonly property string shapeNow: Config.notch.shape
    onShapeNowChanged: bump()
    Connections {
        target: Live
        function onRemindersChanged() { root.bump(); }
        function onAutomoveChanged() { root.bump(); }
        function onNightChanged() { root.bump(); }
        function onRecordingStateChanged() { root.bump(); }
        function onSudoStateChanged() { root.bump(); }
        function onHyprChanged() { root.bump(); }
        function onDndChanged() { root.bump(); }
    }
    Connections { target: Config.widgets; function onLeftChanged() { root.bump(); } function onRightChanged() { root.bump(); } }
    Connections { target: Notifs; function onHistoryChanged() { root.bump(); } function onUnreadChanged() { root.bump(); } function onDndChanged() { root.bump(); } }
    Connections { target: Todo; function onItemsChanged() { root.bump(); } function onSortDoneChanged() { root.bump(); } }
    property string darkNow: ""             // shown at once when you toggle dark mode, until the theme catches up
    Connections { target: Theme; function onModeChanged() { root.darkNow = ""; } }
    function invalidate() { for (const f of allFetch) f.stale(); }

    // ---- ordering
    function ordered(id, nodes) {
        const hidden = orderCfg.hidden || [];
        const want = id === "" ? (orderCfg.order || []) : ((orderCfg.submenus || {})[id] || []);
        const list = nodes.filter(n => hidden.indexOf(n.id) < 0);
        const rank = n => { const i = want.indexOf(n.id); return i < 0 ? 1000 + list.indexOf(n) : i; };
        return list.slice().sort((a, b) => rank(a) - rank(b));
    }

    function childrenOf(node) {
        if (!node) return rootNodes();
        const c = typeof node.children === "function" ? node.children() : (node.children || []);
        // lists that come from live data (apps, networks, devices) keep their own order
        return node.sorted ? c : ordered(node.id, c);
    }

    // the node chain for a list of ids, rebuilt from scratch so every node sees the current state
    function resolve(ids) {
        const nodes = [];
        let list = rootNodes();
        for (const id of ids) {
            const n = list.find(x => x.id === id);
            if (!n) break;
            nodes.push(n);
            list = childrenOf(n);
        }
        return nodes;
    }

    // ---- menu history: what you opened before ranks higher while you search (menus and apps; it stays on this machine)
    property var usage: ({})
    FileView {
        id: usageFile
        path: Config.stateDir + "/menu-usage.json"
        printErrors: false
        onLoaded: { try { root.usage = JSON.parse(text()); } catch (e) { root.usage = {}; } }
    }
    function touch(keys) {
        if (!Config.launcher.menuHistory || !keys.length) return;
        const u = Object.assign({}, usage);
        const now = Date.now();
        for (let i = 1; i <= keys.length; i++) {
            const k = keys.slice(0, i).join("/");
            const cur = u[k] || { n: 0, t: 0 };
            u[k] = { n: cur.n + (i === keys.length ? 1 : 0.4), t: now };       // the menus above it count a little too
        }
        usage = u;
        usageFile.setText(JSON.stringify(u));
    }
    function boost(chain, id) {
        if (!Config.launcher.menuHistory) return 0;
        const r = usage[chain.concat([id]).join("/")];
        if (!r) return 0;
        return 45 * Math.exp(-(Date.now() - r.t) / (7 * 86400000)) + Math.min(r.n, 12) * 5;
    }

    // last highlighted row in each menu (kept while the shell runs, nothing is written to disk)
    property var memory: ({})

    function rootNodes() { return ordered("", [appsMenu(), triggerMenu()].concat(Config.features.systemInfo ? [processesMenu()] : []).concat([weatherNode(), calendarNode(), notificationsMenu(), setupMenu(), installMenu(), removeMenu(), cleanMenu(), learnMenu(), todoMenu(), systemMenu()])); }
    function isMenu(n) { return n.children !== undefined; }

    // ---- search: every node below `scope` (everything when null), with the path it was found under
    // each result carries `chain`: ids of every menu above it, so entering a menu found by search opens that very menu
    function search(scope, query, baseChain) {
        const q = query.trim().toLowerCase();
        const entries = [];
        const hidden = Config.launcher.searchHidden || [];
        function walk(node, trail, chain, depth) {
            for (const c of childrenOf(node)) {
                entries.push({ node: c, trail: trail, chain: chain });
                if (isMenu(c) && !c.noSearch && depth < 4 && hidden.indexOf(chain.concat([c.id]).join("/")) < 0) walk(c, c.flat ? trail : trail.concat(c.name), chain.concat([c.id]), depth + 1);
            }
        }
        walk(scope, scope ? [scope.name] : [], baseChain || [], 0);
        const scored = [];
        for (const e of entries) {
            const s = Fuzzy.scoreFields(q, [
                { text: e.node.name, weight: 1 },
                { text: e.trail.join(" "), weight: 0.45 },
                { text: e.node.keywords || "", weight: 0.6 },
                { text: e.node.sub || "", weight: 0.3 }
            ]);
            // "Remove ..." rows are never what you meant first: the app or web app itself comes before its Remove entry
            const penalty = e.trail.length && e.trail[0] === "Remove" ? 60 : 0;
            if (s >= 0) scored.push({ e: e, s: s + boost(e.chain, e.node.id) - penalty + (isMenu(e.node) ? 0 : 12) });   // things you can run beat folders
        }
        scored.sort((a, b) => b.s - a.s);
        return scored.map(x => x.e);
    }


    // ":grin" at the top level searches emoji only
    function emojiSearch(query) {
        fEmoji.ensure();
        const q = query.trim().toLowerCase();
        const scored = [];
        for (const n of emojiNodes) {
            const sc = Fuzzy.scoreFields(q, [{ text: n.name, weight: 1 }, { text: n.sub, weight: 0.3 }]);
            if (sc >= 0) scored.push({ e: { node: n, trail: ["Emoji"] }, s: sc });
        }
        scored.sort((a, b) => b.s - a.s);
        return scored.map(x => x.e);
    }

    // ================= Trigger
    function toggle(args) { sh(args); }
    function human(n) { return n > 1048576 ? (n / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(n / 1024)) + " KB"; }

    // ---- processes: sorted by CPU / RAM / GPU, typing filters by name, Enter asks before it kills
    property string procSort: "cpu"
    readonly property var procLabels: ({ cpu: "CPU", mem: "RAM", gpu: "GPU" })
    // never offered: the session itself, the shell, the compositor, and v2rayN
    readonly property var procProtected: /^(systemd.*|init|uwsm.*|Hyprland|hyprland.*|qs|quickshell|dbus.*|pipewire.*|wireplumber|v2rayN.*|sshd|login|Xwayland)$/
    function processesMenu() {
        return { id: "processes", name: "Processes", glyph: Icons.chip, keywords: "kill task manager top htop cpu ram gpu memory usage",
                 sub: "Sorted by " + procLabels[procSort], sorted: true,
                 onOpen: () => fProcs.refresh(),
                 children: () => {
            fProcs.ensure();
            const key = procSort;
            const rows = (fProcs.data || []).filter(p => !procProtected.test(p.name) && (key !== "gpu" || p.gpu > 0))
                .sort((a, b) => b[key] - a[key]).slice(0, 300);
            const hasGpu = (fProcs.data || []).some(p => p.gpu > 0);
            const next = key === "cpu" ? "mem" : key === "mem" ? (hasGpu ? "gpu" : "cpu") : "cpu";
            return [{ id: "sort", name: "Sort by " + procLabels[key], glyph: Icons.tune, sub: "Enter: sort by " + procLabels[next] + "  ·  refreshes the list", keep: true,
                      run: () => { procSort = next; fProcs.refresh(); bump(); } }].concat(rows.map(p => ({
                id: "p" + p.pid, name: p.name + "  " + p.pid, glyph: Icons.chip, keep: true,
                sub: "pid " + p.pid,
                badge: key === "gpu" ? p.gpu + "% gpu" : key === "mem" ? p.mem.toFixed(1) + "% ram" : p.cpu.toFixed(1) + "% cpu",
                run: () => ask("Stop " + p.name + " (" + p.pid + ")?  y = stop, 9 = force, Esc cancels", false, a => {
                    const t = a.trim().toLowerCase();
                    if (t === "y") { sh(["kill", String(p.pid)]); say("Stopped " + p.name); }
                    else if (t === "9") { sh(["kill", "-9", String(p.pid)]); say("Killed " + p.name); }
                    else say("Left " + p.name + " alone");
                    fProcs.refresh();
                }) })));
        } };
    }

    // ---- app rules: what happens when a window of an app opens (workspace, in the background, floating)
    Timer { id: rulesRefresh; interval: 400; onTriggered: fRules.refresh() }
    function rule(args) { sh([bin("torii-rules")].concat(args)); rulesRefresh.restart(); }
    function ruleSummary(r) {
        const p = [];
        if (r.workspace) p.push((typeof r.workspace === "string" ? r.workspace.replace(":", " ") : "workspace " + r.workspace) + (r.silent ? " (background)" : ""));
        if (r.float && !r.remember) p.push("floating");
        if (r.remember) p.push("remembers place and size");
        if (r.autostart) p.push("starts at login");
        return p.length ? p.join("  ·  ") : "No effect yet";
    }
    function rulesMenu() {
        const rules = fRules.data || [];
        const have = c => rules.some(r => r.key === c);
        const pick = (cls, name) => ({ id: "add:" + cls, name: name || cls, sub: cls.replace("|", "  ·  popup: "), badge: have(cls) ? "●" : "", keep: true,
            run: () => { if (!have(cls)) rule(["set", cls, "name", name || cls]); say("Added " + (name || cls) + ": open App rules to set it up"); } });
        const specials = (fSpecials.data || []).map(w => w.name);
        const wsLabel = w => typeof w === "string" ? w.replace("special:", "Special ") : "Workspace " + w;
        return { id: "rules", name: "App rules", glyph: Icons.apps, keywords: "window workspace float background open rule deadlock steam",
                 sub: rules.length ? rules.length + " app" + (rules.length > 1 ? "s" : "") : "Workspace, background or floating per app",
                 onOpen: () => { fRules.refresh(); fSpecials.refresh(); },
                 children: () => {
            const ws = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
            const ruleNode = r => ({ id: "r:" + r.key, name: r.name || r.class, sub: ruleSummary(r), glyph: Icons.apps, sorted: true,
                    badge: r.workspace ? String(r.workspace) : "",
                    children: () => [
                    { id: "ws", name: "Workspace", glyph: Icons.monitor, badge: r.workspace ? String(r.workspace) : "None", children: () =>
                        [{ id: "none", name: "None", badge: r.workspace ? "" : "●", keep: true, run: () => rule(["set", r.key, "workspace", "none"]) }].concat(
                            [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(n => ({ id: "w" + n, name: "Workspace " + n, badge: r.workspace === n ? "●" : "", keep: true,
                                run: () => rule(["set", r.key, "workspace", String(n)]) })),
                            (specials.indexOf("special:magic") < 0 ? ["special:magic"] : []).concat(specials).map(n => ({ id: "s:" + n, name: wsLabel(n),
                                sub: "Hidden workspace you toggle with a key", badge: r.workspace === n ? "●" : "", keep: true,
                                run: () => rule(["set", r.key, "workspace", n]) })),
                            [{ id: "newspecial", name: "New special workspace…", keep: true,
                               run: () => ask("Name of the special workspace (letters, digits)", false, t => { if (/^[A-Za-z0-9_-]+$/.test(t.trim())) rule(["set", r.key, "workspace", "special:" + t.trim()]); }) }]) },
                    { id: "silent", name: "Open in the background", sub: "Don't switch to its workspace", badge: r.silent ? "On" : "Off", keep: true,
                      run: () => rule(["set", r.key, "silent", r.silent ? "false" : "true"]) },
                    { id: "float", name: "Open floating", badge: r.float ? "On" : "Off", keep: true, run: () => rule(["set", r.key, "float", r.float ? "false" : "true"]) },
                    { id: "snapshot", name: "Use how it is now", glyph: Icons.camera, sub: "Open the app first: saves its workspace, floating, place and size, background and start at login", keep: true,
                      run: () => { rule(["snapshot", r.class]); say("Saved how " + (r.name || r.class) + " is now"); } },
                    { id: "remember", name: "Remember position and size", sub: "Opens floating where you left it (move and resize it once)", badge: r.remember ? "On" : "Off", keep: true,
                      run: () => rule(["set", r.class, "remember", r.remember ? "false" : "true"]) },
                    { id: "autostart", name: "Start at login", sub: "Opens with the session, on the workspace chosen above", badge: r.autostart ? "On" : "Off", keep: true,
                      run: () => rule(["set", r.class, "autostart", r.autostart ? "false" : "true"]) },
                    { id: "remove", name: "Remove rule", glyph: Icons.trash, sub: r.key.replace("|", "  ·  popup: "), run: () => rule(["remove", r.key]) } ].filter(e => !r.title || ["ws", "silent", "float", "remove"].indexOf(e.id) >= 0) });
            const addNode = { id: "add", name: "Add an app", glyph: Icons.plus, sub: "Pick a window that is open, or an installed app", onOpen: () => fWins.refresh(),
              children: () => [
                { id: "open", name: "Open windows", glyph: Icons.monitor, sub: "The easiest way: open the app first", sorted: true, onOpen: () => fWins.refresh(),
                  children: () => (fWins.data || []).map(w => w.popup
                      ? pick(w.class + "|" + w.initialTitle, (w.title || w.initialTitle).slice(0, 40) + "  ·  popup of " + w.class)
                      : pick(w.class, w.title && w.title.length < 40 ? w.title + "  ·  " + w.class : w.class)) },
                { id: "installed", name: "Installed apps", glyph: Icons.apps, sorted: true,
                  children: () => Apps.items().filter(a => a.kind === "app" || (a.exec && /--class\s+\S+/.test(a.exec)))
                      .map(a => a.kind === "app" ? pick(a.wm || a.id, a.name) : pick(/--class\s+(\S+)/.exec(a.exec)[1], a.name)) },
                { id: "typed", name: "Type a window class…", glyph: Icons.keyboard2, keep: true,
                  run: () => ask("Window class (hyprctl clients shows it)", false, c => { if (c.trim()) rule(["set", c.trim(), "name", c.trim()]); }) } ] };
            const out = [addNode,
                { id: "reopen", name: "Open all saved apps now", glyph: Icons.apps, keep: true,
                  sub: "Starts every app that starts at login and is not open yet; the open ones stay as they are",
                  run: () => { rule(["reopen"]); say("Opening the saved apps"); } },
                { id: "capture", name: "Capture workspace " + ws, glyph: Icons.camera, keep: true,
                  sub: "Replaces what was saved for it: every app here, where it is, floating, place and size, background, start at login",
                  run: () => { rule(["snapshot-workspace", String(ws)]); say("Saved workspace " + ws); } }];
            for (const n of (fSpecials.data || []).filter(w => w.windows > 0).map(w => w.name))
                out.push({ id: "capsp:" + n, name: "Capture " + wsLabel(n).toLowerCase(), glyph: Icons.camera, keep: true,
                           sub: "Same, for the apps on this special workspace (" + n + ")",
                           run: () => { rule(["snapshot-workspace", n]); say("Saved " + wsLabel(n).toLowerCase()); } });
            const groups = {};
            for (const r of rules) (groups[r.workspace ? String(r.workspace) : "-"] = groups[r.workspace ? String(r.workspace) : "-"] || []).push(r);
            const order = k => k === "-" ? 1e9 : isNaN(Number(k)) ? 1000 : Number(k);
            const keys = Object.keys(groups).sort((x, y) => order(x) - order(y) || (x < y ? -1 : 1));
            for (const k of keys) {
                const list = groups[k];
                out.push({ id: "g:" + k, name: k === "-" ? "Not on a workspace" : wsLabel(isNaN(Number(k)) ? k : Number(k)), glyph: Icons.monitor, badge: String(list.length),
                           sub: list.map(r => r.name || r.class).join(", "), sorted: false,
                           children: () => (k === "-" ? [] : [
                               { id: "cap:" + k, name: "Capture workspace " + k + " again", glyph: Icons.camera, keep: true,
                                 sub: "Replaces what is saved for it with the apps on it now (open it the way you want first)", run: () => { rule(["snapshot-workspace", k]); say("Saved workspace " + k); } },
                               { id: "open:" + k, name: "Open workspace " + k + " apps", glyph: Icons.apps, keep: true,
                                 sub: "Starts the saved apps that are not open", run: () => { rule(["reopen", k]); say("Opening workspace " + k); } }]
                               .filter(e => !isNaN(Number(k)) || e.id.indexOf("cap") === 0))
                               .concat(list.map(ruleNode)) });
            }
            return out;
        } };
    }

    // ---- sounds: pick the file for reminders and for notifications (it plays as a preview)
    function soundsMenu() {
        const dir = home + "/.config/torii/sounds";
        const kind = (k, label) => ({ id: k, name: label, glyph: Icons.bell, sub: Config.sounds[k] || "Default (" + k + ".*)", onOpen: () => fSounds.refresh(),
            children: () => [{ id: "default", name: "Default", sub: k + ".* in the sounds folder", badge: Config.sounds[k] ? "" : "●", keep: true,
                               run: () => { sh([bin("torii-config"), "set", "sounds." + k, '""']); sh([bin("torii-sound"), k]); } }].concat(
                (fSounds.data || []).map(f => ({ id: "f:" + f, name: f, glyph: Icons.music, badge: Config.sounds[k] === f ? "●" : "", keep: true,
                    run: () => { sh([bin("torii-config"), "set", "sounds." + k, JSON.stringify(f)]); sh([bin("torii-sound"), "play", f]); } })))
                .concat([{ id: "folder", name: "Open the sounds folder", glyph: Icons.folderMove, sub: "Drop .ogg, .wav, .mp3 or .flac files in", keep: true, run: () => sh(["xdg-open", dir]) }]) });
        return { id: "sounds", name: "Sounds", glyph: Icons.bell, keywords: "reminder notification alert ogg volume", sub: "Reminder and notification sounds",
                 children: () => [kind("reminder", "Reminder"), kind("notification", "Notification")] };
    }

    // ---- widgets around the notch (shown while the launcher or the control panel is open)
    function widgetsMenu() {
        const names = { system: "System load", claude: "Claude usage", battery: "Battery" };
        const left = Config.widgets.left || [], right = Config.widgets.right || [];
        const place = id => left.indexOf(id) >= 0 ? "Left" : right.indexOf(id) >= 0 ? "Right" : "Off";
        const put = (id, side) => {
            const l = left.filter(x => x !== id), r = right.filter(x => x !== id);
            if (side === "Left") l.push(id); else if (side === "Right") r.push(id);
            sh(["sh", "-c", bin("torii-config") + " set widgets.left '" + JSON.stringify(l) + "' && " + bin("torii-config") + " set widgets.right '" + JSON.stringify(r) + "'"]);
        };
        return { id: "widgets", name: "Widgets", glyph: Icons.apps, keywords: "notch system battery claude cpu left right hide",
                 sub: "What shows around the notch while the launcher is open",
                 children: () => Object.keys(names).filter(id => id !== "system" || Config.features.systemInfo).map(id => ({
                    id: id, name: names[id], sub: id === "battery" ? "Only on a laptop" : id === "claude" ? "Needs a signed-in Claude Code" : "CPU, RAM, GPU, temperatures",
                    badge: place(id), children: () => ["Left", "Right", "Off"].map(side => ({
                        id: side.toLowerCase(), name: side, badge: place(id) === side ? "●" : "", keep: true, run: () => put(id, side) })) })) };
    }

    // panels that open in place of the launcher
    function weatherNode() {
        return { id: "weather", name: "Weather", glyph: Weather.glyph, keywords: "forecast rain temperature wind",
                 sub: Weather.available ? Math.round(Weather.temp) + "°  ·  " + Weather.describe(Weather.code) : "Forecast", keep: true,
                 run: () => Panels.open("weather") };
    }
    function notificationsMenu() {
        const h = Notifs.history;
        return { id: "notifications", name: "Notifications", glyph: Notifs.dnd ? Icons.bellOff : Icons.bell, keywords: "messages alerts inbox history do not disturb",
                 sub: h.length ? h[0].summary : "Nothing new", badge: Notifs.badgeVisible ? String(Notifs.unread) : "", sorted: true,
                 onOpen: () => Notifs.markRead(),
                 children: () => [
            { id: "dnd", name: "Do not disturb", glyph: Notifs.dnd ? Icons.bellOff : Icons.bell, badge: Notifs.dnd ? "On" : "Off", keep: true, run: () => Notifs.toggleDnd() },
            { id: "clear", name: "Clear all", glyph: Icons.trash, keep: true, run: () => Notifs.clear() } ].concat(
                h.map(e => ({ id: "n" + e.uid, name: e.summary || e.app, glyph: Icons.bell, icon: (e.icon || "").indexOf("image:") === 0 ? undefined : (e.icon || undefined),
                              sub: [e.app, e.body.split("\n")[0], Notifs.ago(e.time)].filter(x => x).join("  ·  "),
                              run: () => Notifs.activate(e) }))) };
    }
    function calendarNode() {
        return { id: "calendar", name: "Calendar", glyph: Icons.calendar, keywords: "date month day", sub: "This month", keep: true,
                 run: () => Panels.open("calendar") };
    }

    function triggerMenu() {
        const t = { automove: Live.automove, dnd: Live.dnd, recording: Live.recording, hypr: Live.hypr, shape: shapeNow };
        const hyprBin = bin("torii-hypr");
        return { id: "trigger", name: "Trigger", glyph: Icons.flash, sub: "Capture, convert, remind, switches", children: () => [
            captureMenu(t),
            transcodeMenu(),
            { id: "emoji", name: "Emoji", glyph: Icons.emoji, sub: "Copy and type an emoji", noSearch: true, sorted: true, grid: true,
              children: () => { fEmoji.ensure(); return emojiNodes; } },
            { id: "pushprivate", name: "Push private backup", glyph: Icons.flash, keywords: "backup telegram discord login browser profile server torii-private",
              sub: "Browser profile, web app logins, your apps → the home servers (close Helium and the web apps first)",
              run: () => floatTerm("Push private backup", ["sh", "-c", 'bash "$(dirname "$(readlink -f ~/.config/quickshell)")/../packages/private-push.sh"; printf "\\nPress Enter to close "; read _']) },
            { id: "reminder", name: "Reminder", glyph: Icons.timer, keywords: "timer alarm notify cancel stop", keep: true,
              sub: Live.reminders.length ? Live.reminders.length + " active  ·  → to see or stop them" : "In some minutes, with a message",
              badge: Live.reminders.length ? String(Live.reminders.length) : "",
              run: () => newReminder(),
              children: () => [{ id: "new", name: "New reminder…", glyph: Icons.plus, keep: true, run: () => newReminder() }].concat(
                  Live.reminders.map(r => ({ id: "r" + r.id, name: r.msg || "Reminder", glyph: Icons.timer, keep: true,
                      sub: Math.max(1, Math.round(Live.remaining(r) / 60)) + " min left  ·  Enter stops it",
                      run: () => sh([bin("torii-remind"), "cancel", r.id]) }))) },
            { id: "automove", name: "File auto mover", glyph: Icons.folderMove, keywords: "downloads move inbox photos",
              sub: t.automove.enabled ? "Files → " + (t.automove.to || "").replace(home, "~") + "  ·  zips → " + (t.automove.unzipTo || "").replace(home, "~") : "Downloads → " + (t.automove.to || "your inbox folder").replace(home, "~"),
              badge: t.automove.enabled ? "On" : "Off", keep: true, run: () => toggle([bin("torii-automove"), t.automove.enabled ? "off" : "on"]) },
            { id: "mic", name: "Microphone", glyph: Audio.sourceMuted ? Icons.micOff : Icons.mic, keywords: "input mic mute unmute",
              sub: !Audio.sourceNode && !Audio.mock ? "No microphone found" : Audio.sourceMuted ? "Muted" : "Listening",
              badge: !Audio.sourceNode && !Audio.mock ? "" : Audio.sourceMuted ? "Off" : "On", keep: true,
              run: () => { if (Audio.sourceNode || Audio.mock) Audio.toggleSourceMute(); else say("No microphone found"); } },
            { id: "dnd", name: "Do not disturb", glyph: t.dnd ? Icons.bellOff : Icons.bell, keywords: "notifications silence",
              sub: "Notifications", badge: t.dnd ? "On" : "Off", keep: true, run: () => Notifs.toggleDnd() },
            { id: "dark", name: "Dark mode", glyph: Icons.themeDark, keywords: "light theme appearance",
              badge: (darkNow || Theme.mode) === "dark" ? "On" : "Off", keep: true,
              run: () => { darkNow = (darkNow || Theme.mode) === "dark" ? "light" : "dark"; sh([bin("torii-theme"), "mode", darkNow]); } },
            sudoNode(),
            { id: "shape", name: "Menu bar shape", glyph: Icons.layout, keywords: "notch floating attached",
              sub: t.shape === "floating" ? "Floating" : "Attached", badge: t.shape === "floating" ? "Floating" : "Attached", keep: true,
              run: () => { sh([bin("torii-config"), "set", "notch.shape", t.shape === "floating" ? '"attached"' : '"floating"']); } },
            { id: "layout", name: "Workspace layout", glyph: Icons.layout, sub: t.hypr.layout || "dwindle", keywords: "tiling dwindle master scrolling", children: () =>
                [["dwindle", "Split in halves, newest window splits the focused one"], ["master", "One big window and a stack"], ["scrolling", "Columns that scroll sideways"]].map(l => ({
                    id: l[0], name: l[0].charAt(0).toUpperCase() + l[0].slice(1), sub: l[1], badge: (t.hypr.layout || "dwindle") === l[0] ? "●" : "", keep: true,
                    run: () => { sh([hyprBin, "layout", l[0]]); } })) },
            { id: "gaps", name: "Window gaps", glyph: Icons.layout, sub: (t.hypr.gaps_in ?? 8) + " / " + (t.hypr.gaps_out ?? 20), keywords: "spacing margin", children: () =>
                [["None", 0, 0], ["Tight", 2, 5], ["Small", 4, 10], ["Default", 8, 20], ["Large", 12, 32]].map(g => ({
                    id: "g" + g[0], name: g[0], sub: g[1] + " inside, " + g[2] + " outside", badge: (t.hypr.gaps_out ?? 20) === g[2] ? "●" : "", keep: true,
                    run: () => { sh([hyprBin, "gaps", String(g[1]), String(g[2])]); } })) },
            { id: "appsync", name: "Add ~/apps to the app menu", glyph: Icons.apps, sub: "Makes .desktop entries for the folders in ~/apps", keywords: "generate desktop entries portable",
              run: () => sh([bin("torii-apps"), "desktop"]) },
            { id: "speed", name: "Speed test", glyph: Icons.speed, sub: "Network or disk, result as a notification", children: () => [
                { id: "net", name: "Network", sub: "Download, upload, latency", glyph: Icons.wifi, run: () => app([bin("torii-speed"), "net"]) },
                { id: "disk", name: "Disk", sub: "Write and read 512 MB in your home folder", glyph: Icons.folder, run: () => app([bin("torii-speed"), "disk"]) } ] }
        ] };
    }

    // passwordless sudo: needs your password once to switch it on (never stored), off needs none while it is on
    Process {
        id: feeder
        property string feed: ""
        property var done: null
        stdinEnabled: true
        onStarted: { write(feed + "\n"); stdinEnabled = false; feed = ""; }
        onExited: code => { stdinEnabled = true; if (done) done(code); }
    }
    function runWithInput(args, text, done) {
        feeder.command = args; feeder.feed = text; feeder.done = done; feeder.running = true;
    }
    function sudoOn(arg, label) {
        ask("Password (needed once)", true, pw => runWithInput([bin("torii-sudo"), "on", arg], pw, code => {
            say(code === 0 ? "Passwordless sudo on " + label : "Wrong password");
        }));
    }
    function sudoNode() {
        const on = Live.sudoOn;
        const left = Live.sudoState.until > 0 ? Math.max(0, Math.round((Live.sudoState.until - Live.now / 1000) / 60)) : -1;
        return { id: "sudo", name: "Passwordless sudo", glyph: Icons.lock, keywords: "root password nopasswd",
                 sub: on ? (left >= 0 ? "On, about " + left + " min left" : "On until reboot") : "For 5 minutes or until reboot",
                 badge: on ? "On" : "", children: () => [
            { id: "5m", name: "For 5 minutes", sub: "Switches off by itself", glyph: Icons.timer, keep: true, run: () => sudoOn("5m", "for 5 minutes") },
            { id: "boot", name: "Until reboot", sub: "Removed at the next boot or shutdown", glyph: Icons.power, keep: true, run: () => sudoOn("boot", "until reboot") },
            { id: "off", name: "Turn off", sub: on ? "" : "Not on right now", glyph: Icons.close, keep: true,
              run: () => { if (!on) return; runWithInput([bin("torii-sudo"), "off"], "", code => say(code === 0 ? "Passwordless sudo off" : "Could not turn it off")); } } ] };
    }

    function newReminder() {
        ask("Remind me in (minutes)", false, m => {
            const n = parseFloat(String(m).replace(",", "."));
            if (!(n > 0)) { say("Type a number of minutes, like 25"); return; }
            ask("Remind me about…", false, msg => {
                sh([bin("torii-remind"), "add", String(n), msg || "Time is up"]);
                Panels.close();
            });
        });
    }

    function captureMenu(t) {
        const cap = what => () => app([bin("torii-capture"), what]);
        return { id: "capture", name: "Capture", glyph: Icons.camera, sub: "Screenshot, record, text, QR, colour", children: () => [
            { id: "screen", name: "Screenshot", sub: "The whole screen", glyph: Icons.camera, keywords: "screenshot fullscreen", run: cap("screen") },
            { id: "zone", name: "Screenshot zone", sub: "Drag a rectangle", glyph: Icons.camera, keywords: "screenshot region area", run: cap("zone") },
            { id: "record", name: t.recording ? "Stop recording" : "Record screen", sub: "The focused monitor, saved in ~/Videos", glyph: Icons.record,
              keywords: "video screencast", badge: t.recording ? "●" : "", run: cap("record") },
            { id: "text", name: "Text from screen", sub: "Drag a rectangle, the text is copied", glyph: Icons.textScan, keywords: "ocr read copy", run: cap("text") },
            { id: "qr", name: "QR code", sub: "Drag a rectangle around it", glyph: Icons.qr, keywords: "scan barcode", run: cap("qr") },
            { id: "freeze", name: "Freeze screen while selecting", sub: "Zone, text and QR: the picture stands still while you drag (needs wayfreeze)", glyph: Icons.camera,
              badge: Config.capture.freeze ? "On" : "Off", keep: true,
              run: () => sh([bin("torii-config"), "set", "capture.freeze", Config.capture.freeze ? "false" : "true"]) },
            { id: "color", name: "Colour picker", sub: "Click a pixel, the hex is copied", glyph: Icons.eyedropper, keywords: "color eyedropper hex", run: cap("color") }
        ] };
    }

    // transcode: file -> format -> size
    function transcodeMenu() {
        return { id: "transcode", name: "Transcode", glyph: Icons.swap, sub: "Convert images and videos", keywords: "convert resize png jpg webp mp4 mov gif", sorted: true, children: () => {
            fTrans.ensure();
            const out = (fTrans.data || []).map(fileNode);
            if (pendingFile) out.unshift(fileNode(pendingFile));
            out.push({ id: "path", name: "Another file…", sub: "Type or paste a path", glyph: Icons.pencil, keep: true,
                       run: () => ask("Path of the file", false, p => {
                           const path = p.replace(/^~/, home).replace(/^["']|["']$/g, "");
                           const ext = (path.split(".").pop() || "").toLowerCase();
                           if (!path) return;
                           pendingFile = { path: path, name: path.split("/").pop(), dir: "your file", size: 0,
                                           kind: ["mp4", "mov", "mkv", "webm", "avi", "gif", "m4v"].indexOf(ext) >= 0 ? "video" : "image" };
                           bump(); }) });
            if (!(fTrans.data || []).length && !pendingFile) out.unshift({ id: "none", name: "No recent media found", sub: "Downloads, Pictures, Videos" });
            return out;
        } };
    }
    property var pendingFile: null
    function fileNode(f) {
        return { id: "f:" + f.path, name: f.name, sub: f.dir + (f.size ? "  ·  " + human(f.size) : ""), glyph: f.kind === "image" ? Icons.image : Icons.video,
                 noSearch: true, children: () => formatsFor(f) };
    }
    function formatsFor(f) {
        const ext = f.name.split(".").pop().toLowerCase();
        const fmts = f.kind === "image" ? ["png", "jpg", "jpeg", "webp"] : ["mp4", "mov", "gif"];
        return fmts.filter(x => x !== ext).map(x => ({ id: x, name: x.toUpperCase(), sub: "Convert " + f.name, glyph: Icons.swap, children: () => sizesFor(f, x) }));
    }
    function sizesFor(f, fmt) {
        const img = f.kind === "image";
        const list = [["orig", "Original size"], ["p75", "75 %"], ["p50", "50 %"], ["p25", "25 %"]].concat(img
            ? [["w3840", "3840 px wide"], ["w1920", "1920 px wide"], ["w1280", "1280 px wide"], ["w800", "800 px wide"]]
            : [["h1080", "1080p"], ["h720", "720p"], ["h480", "480p"], ["h360", "360p"]]);
        return list.map(z => ({ id: z[0], name: z[1], glyph: Icons.tune, sub: f.name + " → " + fmt, run: () => app([bin("torii-transcode"), "run", f.path, fmt, z[0]]) }));
    }


    // ================= Install / Remove
    function floatTerm(title, args) { app(["kitty", "--class", "torii-float", "--title", title].concat(args)); }

    function installMenu() {
        return { id: "install", name: "Install", glyph: Icons.download, sub: "Packages, web apps, terminal apps, updates", keywords: "add package pacman aur yay web app tui update",
                 children: () => {
            fGit.ensure();
            const g = fGit.data || {};
            const gitBadge = g.dirty ? "● changes" : (g.behind ? "↓ " + g.behind : "") + (g.behind && g.ahead ? "  " : "") + (g.ahead ? "↑ " + g.ahead : "");
            return [
                { id: "pacman", name: "Package", sub: "Search the repositories (Tab picks several)", glyph: Icons.download, keywords: "pacman install software",
                  run: () => floatTerm("Install", [bin("torii-install"), "pacman"]) },
                { id: "aur", name: "AUR package", sub: "Search the AUR with yay", glyph: Icons.download, keywords: "yay install software",
                  run: () => floatTerm("Install from the AUR", [bin("torii-install"), "aur"]) },
                { id: "webapp", name: "Web app", sub: "A website in its own window (Helium)", glyph: Icons.web, keywords: "website pwa chromium helium", keep: true,
                  run: () => ask("Name of the web app", false, name => {
                      if (!name) return;
                      ask("Address of " + name + " (https://…)", false, url => {
                          if (!url) return;
                          sh([bin("torii-apps"), "webapp", "add", name, url]); later(fWeb, 1500);
                          say(name + " added, it is in Apps in a moment");
                      });
                  }) },
                { id: "tui", name: "Terminal app", sub: "A command in a terminal window, e.g. ssh to a server", glyph: Icons.terminal, keywords: "tui command ssh", keep: true,
                  run: () => ask("Name of the terminal app", false, name => {
                      if (!name) return;
                      ask("Command to run for " + name, false, cmd => {
                          if (!cmd) return;
                          sh([bin("torii-apps"), "tui", "add", name, cmd]); later(fTui, 800);
                          say(name + " added, it is in Apps");
                      });
                  }) },
                { id: "update", name: "Update system", sub: "pacman and AUR upgrade", glyph: Icons.update, keywords: "upgrade yay pacman -Syu",
                  run: () => floatTerm("Update", [bin("torii-install"), "update"]) },
                syncMenu(g, gitBadge)
            ];
        } };
    }

    // ---- Sync: tick what to push to GitHub and the private server torii-private; pull always brings everything
    property var syncSel: ({ configs: true, helium: false, webapps: false, apps: false, localsend: false })
    readonly property var syncItems: [
        { k: "configs", name: "Configs", sub: "Hyprland, shell, app rules, notch look… (the dotfiles repo on GitHub)" },
        { k: "helium", name: "Helium profile", sub: "Cookies, extensions, bookmarks, settings (about 400 MB, torii-private)" },
        { k: "webapps", name: "Web apps and logins", sub: "Telegram, Discord… and that they stay signed in (torii-private)" },
        { k: "apps", name: "My desktop apps", sub: "Only the apps ticked below, with the ~/apps folder they use (torii-private)" },
        { k: "localsend", name: "LocalSend settings", sub: "Name, port and key (torii-private)" } ]
    // "(up icon) 3  (down icon) 1": files newer here (would be pushed) and newer on GitHub / the server (would be pulled); "…" while it is being checked
    function syncBadge(k) {
        const st = fSyncStatus.data ? fSyncStatus.data[k] : null;
        const part = v => v === null || v === undefined ? "?" : String(v);
        const counts = st ? (st.up === 0 && st.down === 0 ? "in sync" : Icons.upload + " " + part(st.up) + "   " + Icons.download + " " + part(st.down)) : "…";
        // an open browser keeps changing its files: the "up" count then is not a real difference
        const open = fSyncStatus.data && fSyncStatus.data.heliumOpen && (k === "helium" || k === "webapps") && st && st.up > 0 ? "  (Helium is open)" : "";
        return (syncSel[k] ? "✓  " : "") + counts + open;
    }
    function syncChosen() { return syncItems.filter(i => syncSel[i.k]).map(i => i.k); }
    function syncMenu(g, gitBadge) {
        const chosen = syncChosen();
        const tick = i => ({ id: "t:" + i.k, name: i.name, sub: i.sub, badge: syncBadge(i.k), keep: true, glyph: i.k === "configs" ? Icons.git : Icons.apps,
            run: () => { const n = Object.assign({}, syncSel); n[i.k] = !n[i.k]; syncSel = n; bump(); } });
        const run = (verb, label, sub) => ({ id: verb, name: label, sub: chosen.length ? sub : "Tick something above first", glyph: verb === "push" ? Icons.upload : Icons.download,
            run: () => { if (chosen.length) floatTerm("Sync " + verb, [bin("torii-sync"), verb].concat(chosen)); else say("Tick something first"); } });
        return { id: "dotfiles", name: "Sync torii", glyph: Icons.git, keywords: "dotfiles git pull push sync update configs backup helium private",
                 sub: g.error ? "No remote to compare with" : g.dirty ? "Local changes not pushed" : g.behind ? g.behind + " new commits to pull" : g.ahead ? g.ahead + " commits to push" : "Configs are up to date",
                 badge: gitBadge, onOpen: () => { fGit.refresh(); fSyncApps.refresh(); fSyncStatus.refresh(); },
                 children: () => {
            fGit.ensure(); fSyncApps.ensure(); fSyncStatus.ensure();
            const apps = (fSyncApps.data || []).map(a => ({ id: "a:" + a.file, name: a.file.replace(/\.desktop$/, ""), badge: a.on ? "✓" : "", keep: true, glyph: Icons.apps,
                run: () => { sh([bin("torii-sync"), "toggle-app", a.file]); later(fSyncApps, 300); } }));
            return syncItems.map(tick).concat([
                { id: "appslist", name: "Choose desktop apps…", sub: "Which of your .desktop apps “My desktop apps” saves", glyph: Icons.apps, onOpen: () => fSyncApps.refresh(),
                  children: () => apps.length ? apps : [{ id: "none", name: "No own .desktop apps", sub: "Apps made by torii are rebuilt on install and not listed" }] },
                run("push", "Push ticked now", "Saves this computer's version, replacing the copy on GitHub / the server. Asks first"),
                { id: "pull", name: "Pull everything now", sub: "Brings all of it from GitHub and torii-private, whatever is ticked. Replaces files here (private ones: old copies kept as .bak; configs: your uncommitted changes stay). Asks first",
                  glyph: Icons.download, run: () => floatTerm("Sync pull", [bin("torii-sync"), "pull", "all"]) } ]);
        } };
    }

    function removeMenu() {
        return { id: "remove", name: "Remove", glyph: Icons.trash, sub: "Packages, web apps, terminal apps", keywords: "uninstall delete",
                 children: () => {
            fWeb.ensure(); fTui.ensure();
            const mk = (fetch, kind, label) => (fetch.data || []).map(w => ({
                id: kind + ":" + w.name, name: w.name, sub: label + "  ·  " + (w.url || w.command || ""), glyph: kind === "webapp" ? Icons.web : Icons.terminal, keep: true,
                run: () => {
                    sh([bin("torii-apps"), kind, "remove", w.name]);
                    fetch.data = (fetch.data || []).filter(x => x.name !== w.name);
                    say("Removed " + w.name);
                } }));
            return [
                { id: "package", name: "Package", sub: "Pick installed packages to remove (Tab picks several)", glyph: Icons.trash, keywords: "pacman uninstall software",
                  run: () => floatTerm("Remove", [bin("torii-install"), "remove"]) },
                { id: "webapp", name: "Web app", sub: (fWeb.data || []).length + " added", glyph: Icons.web, keywords: "website",
                  children: () => { const l = mk(fWeb, "webapp", "Web app"); return l.length ? l : [{ id: "none", name: "No web apps yet", sub: "Install > Web app" }]; } },
                { id: "tui", name: "Terminal app", sub: (fTui.data || []).length + " added", glyph: Icons.terminal, keywords: "tui command",
                  children: () => { const l = mk(fTui, "tui", "Terminal app"); return l.length ? l : [{ id: "none", name: "No terminal apps yet", sub: "Install > Terminal app" }]; } }
            ];
        } };
    }

    // ================= Learn
    function learnMenu() {
        const keysMenu = (id, name, fetch, hint) => ({ id: id, name: name, glyph: Icons.keyboard2, sub: hint + "  ·  Enter opens the config", sorted: true, children: () => {
            fetch.ensure();
            const l = (fetch.data || []).map((e, i) => ({ id: id + i, name: e.keys, sub: e.desc, keywords: e.desc, glyph: Icons.keyboard,
                run: () => floatTerm(name + " config", ["sh", "-c", 'exec "${EDITOR:-nvim}" "+$1" "$2"', "sh", String(e.line || 1), e.file]) }));
            return l.length ? l : [{ id: "none", name: "Nothing found", sub: "No shortcuts in that config" }];
        } });
        return { id: "learn", name: "Learn", glyph: Icons.book, sub: "Your keyboard shortcuts and notes", keywords: "shortcuts keybindings cheatsheet help",
                 children: () => {
            fNotes.ensure();
            const notes = (fNotes.data || []).map(n => ({ id: "note:" + n.path, name: n.name, sub: "Note  ·  " + n.path.replace(home, "~"), glyph: Icons.book,
                                                         run: () => floatTerm(n.name, ["sh", "-c", 'exec "${EDITOR:-nvim}" -R "$1"', "sh", n.path]) }));
            return [keysMenu("lhypr", "Hyprland", fLearnHypr, "binds.lua"), keysMenu("ltmux", "tmux", fLearnTmux, "tmux.conf"), keysMenu("lnvim", "Neovim", fLearnNvim, "init.lua and plugins")].concat(notes);
        } };
    }

    // ================= Todo
    function todoMenu() {
        return { id: "todo", name: "Todo", glyph: Icons.checklist, sub: Todo.openCount + " open", keywords: "tasks list checklist",
                 children: () => {
            const out = [{ id: "add", name: "Add…", glyph: Icons.plus, keep: true, run: () => ask("New todo", false, t => { Todo.add(t); }) }];
            for (const i of Todo.shown) {
                out.push({ id: "t" + i.id, name: i.text, glyph: i.done ? Icons.todoDone : Icons.todoOpen, badge: i.done ? "done" : "", keep: true,
                           run: () => Todo.toggle(i.id),
                           children: () => [
                               { id: "toggle", name: i.done ? "Mark as open" : "Mark as done", glyph: Icons.check, keep: true, run: () => Todo.toggle(i.id) },
                               { id: "edit", name: "Edit…", glyph: Icons.pencil, keep: true, run: () => ask("Change “" + i.text + "” to", false, t => Todo.edit(i.id, t)) },
                               { id: "remove", name: "Remove", glyph: Icons.trash, keep: true, run: () => Todo.remove(i.id) } ] });
            }
            if (Todo.items.some(i => i.done)) out.push({ id: "clear", name: "Clear finished", glyph: Icons.trash, keep: true, run: () => Todo.clearDone() });
            out.push({ id: "sort", name: "Finished at the bottom", glyph: Icons.tune, badge: Todo.sortDone ? "On" : "Off", keep: true, run: () => Todo.setSortDone(!Todo.sortDone) });
            return out;
        } };
    }

    // ================= System (last)
    function confirm(label, args) { ask(label + "?  Enter to confirm, Esc to cancel", false, () => sh(args)); }
    function systemMenu() {
        return { id: "system", name: "System", glyph: Icons.poweroff, sub: "Shut down, restart, log out, sleep", keywords: "power shutdown poweroff reboot restart logout suspend",
                 children: () => [
            { id: "poweroff", name: "Shut down", glyph: Icons.poweroff, keep: true, run: () => confirm("Shut down", ["systemctl", "poweroff"]) },
            { id: "reboot", name: "Reboot", glyph: Icons.restart, keep: true, run: () => confirm("Reboot", ["systemctl", "reboot"]) },
            { id: "logout", name: "Log out", glyph: Icons.logout, keep: true, run: () => confirm("Log out", ["sh", "-c", "uwsm stop || hyprctl dispatch 'hl.dsp.exit()'"]) },
            { id: "suspend", name: "Sleep", glyph: Icons.sleep, keep: true, run: () => confirm("Suspend", ["systemctl", "suspend"]) } ] };
    }

    // ================= Apps
    function appsMenu() {
        return { id: "apps", name: "Apps", glyph: Icons.apps, sub: "Everything installed", sorted: true, flat: true,
                 children: () => Apps.items().map(i => ({
                     id: i.key, name: i.name, sub: i.sub, icon: i.icon, keywords: i.extra, run: () => Apps.run(i)
                 })).sort((a, b) => a.name.localeCompare(b.name)) };
    }

    // ================= Setup
    function setupMenu() {
        return { id: "setup", name: "Setup", glyph: Icons.cog, sub: "Configs, defaults, night light, network",
                 children: () => [configsMenu(), defaultsMenu(), nightMenu(), widgetsMenu(), appearanceMenu(), windowsMenu(), searchMenu(), calendarSetupMenu(), soundsMenu(), rulesMenu(), networkMenu(), bluetoothMenu(), audioMenu("input"), audioMenu("output"), mouseNode()] };
    }

    // ================= Clean up: caches, logs, Docker, big files (torii-clean)
    function cleanMenu() {
        const items = fClean.data || [];
        const totalBytes = items.reduce((n, i) => n + (i.size || 0), 0);
        const human = n => n >= 1073741824 ? (n / 1073741824).toFixed(1) + " GiB" : n >= 1048576 ? (n / 1048576).toFixed(0) + " MiB" : (n / 1024).toFixed(0) + " KiB";
        const term = (title, ids) => floatTerm(title, ["sh", "-c", bin("torii-clean") + " run " + ids.join(" ") + '; printf "\\nPress Enter to close "; read _']);
        const after = () => { later(fClean, 4000); later(fBig, 4500); };
        return { id: "clean", name: "Clean up", glyph: Icons.trash, sub: items.length ? human(totalBytes) + " can be freed" : "Caches, logs, Docker, big files",
                 keywords: "cleanup free space disk cache logs journal docker downloads big files trash temp", onOpen: () => { fClean.refresh(); fBig.refresh(); },
                 children: () => {
            const rows = [{ id: "safe", name: "Clean everything safe", glyph: Icons.trash, badge: human(totalBytes),
                            sub: "Trash, caches, package downloads, logs, crash dumps, Docker. Asks for your password in a terminal",
                            run: () => { term("Clean up", ["safe"]); after(); } }];
            for (const i of items)
                rows.push({ id: "c:" + i.id, name: i.name, sub: i.sub, glyph: Icons.trash, badge: i.human || "", keep: false,
                            run: () => { term("Clean up: " + i.name, [i.id]); after(); } });
            const big = fBig.data || [];
            rows.push({ id: "big", name: "Big files", glyph: Icons.folder, sub: big.length ? big.length + " files over 100 MB in your folders" : "Nothing over 100 MB in Downloads, Documents, Videos, Pictures, Desktop",
                        badge: big.length ? human(big.reduce((n, f) => n + f.size, 0)) : "", keywords: "large files downloads videos documents pictures desktop",
                        children: () => (fBig.data || []).map(f => ({ id: "f:" + f.path, name: f.name, sub: f.dir.replace(home, "~") + "  ·  " + f.age + " days old", badge: f.human, glyph: Icons.folder,
                            children: () => [
                                { id: "trash", name: "Move to trash", glyph: Icons.trash, sub: "It can be restored from the trash", keep: true,
                                  run: () => { sh([bin("torii-clean"), "trash", f.path]); say("Moved to the trash: " + f.name); later(fBig, 1200); later(fClean, 1500); } },
                                { id: "open", name: "Show in files", glyph: Icons.folder, run: () => app(["xdg-open", f.dir]) } ] })) });
            return rows;
        } };
    }

    // which menus the launcher search looks inside (the menu itself is always found; its rows only when this is on)
    function searchMenu() {
        return { id: "search", name: "Launcher search", glyph: Icons.search, sub: "Which menus show their rows when you type",
                 keywords: "hide menus fzf clutter results", noSearch: true, children: () => {
            const hidden = Config.launcher.searchHidden || [];
            const rows = [];
            const add = (chain, node) => {
                const path = chain.concat([node.id]).join("/");
                const off = hidden.indexOf(path) >= 0;
                rows.push({ id: "s:" + path, name: chain.length ? node.name + "  ·  " + chain.join(" › ") : node.name,
                            sub: off ? "Rows inside are not searched" : "Rows inside show up in the search", badge: off ? "Off" : "On", keep: true,
                            run: () => {
                                const next = off ? hidden.filter(x => x !== path) : hidden.concat([path]);
                                sh([bin("torii-config"), "set", "launcher.searchHidden", JSON.stringify(next)]);
                            } });
            };
            for (const top of rootNodes()) {
                if (!isMenu(top) || top.noSearch) continue;
                if (top.id !== "setup") add([], top);
                const ids = [top.id];
                for (const sub of childrenOf(top)) {
                    if (isMenu(sub) && !sub.noSearch && !sub.flat && sub.id !== "search") {
                        const p = ids.concat([sub.id]).join("/"), off = hidden.indexOf(p) >= 0;
                        rows.push({ id: "s:" + p, name: sub.name + "  ·  " + top.name, sub: off ? "Rows inside are not searched" : "Rows inside show up in the search",
                                    badge: off ? "Off" : "On", keep: true,
                                    run: () => sh([bin("torii-config"), "set", "launcher.searchHidden", JSON.stringify(off ? hidden.filter(x => x !== p) : hidden.concat([p]))]) });
                    }
                }
            }
            return rows;
        } };
    }

    // floating mode and the title bars (hyprbars)
    function windowsMenu() {
        fHypr.ensure();
        const d = fHypr.data || {};
        const bars = d.bars || { height: 28, side: "right" };
        const floatOn = d.float === "float";
        const refresh = () => later(fHypr, 700);
        return { id: "windows", name: "Windows", glyph: Icons.layout, sub: (floatOn ? "Floating" : "Tiled") + "  ·  buttons " + bars.side,
                 keywords: "float floating tile title bar buttons close minimise maximise", children: () => [
            { id: "float", name: floatOn ? "Switch to tiled" : "Switch to floating", glyph: Icons.layout, badge: floatOn ? "Floating" : "Tiled", keep: true,
              sub: "Alt+Shift+N  ·  every window floats with a title bar, and remembers its size and place",
              run: () => { sh([bin("torii-hypr"), "float", "toggle"]); refresh(); } },
            { id: "barh", name: "Title bar height", glyph: Icons.tune, sub: "On floating windows",
              slider: { min: 16, max: 56, step: 1, value: bars.height, unit: " px", decimals: 0 },
              onSlide: v => sh([bin("torii-hypr"), "bars", "height", String(v)]) },
            { id: "bigsize", name: "Big window size", glyph: Icons.tune, sub: "Ctrl+Alt+Shift+Up: how much of the screen the window takes",
              slider: { min: 30, max: 100, step: 5, value: d.bigPercent === undefined ? 70 : d.bigPercent, unit: " %", decimals: 0 },
              onSlide: v => sh([bin("torii-hypr"), "size", String(v)]) },
            { id: "side", name: "Buttons", glyph: Icons.layout, sub: bars.side === "left" ? "Left (close, minimise, maximise)" : "Right (minimise, maximise, close)", children: () => [
                { id: "l", name: "Left", sub: "Like macOS: close, minimise, maximise", badge: bars.side === "left" ? "●" : "", keep: true,
                  run: () => { sh([bin("torii-hypr"), "bars", "side", "left"]); refresh(); } },
                { id: "r", name: "Right", sub: "Like Windows: minimise, maximise, close", badge: bars.side === "right" ? "●" : "", keep: true,
                  run: () => { sh([bin("torii-hypr"), "bars", "side", "right"]); refresh(); } } ] } ] };
    }

    function calendarSetupMenu() {
        fCalSync.ensure();
        const cs = fCalSync.data || { configured: false, on: false, minutes: 15 };
        const refresh = () => later(fCalSync, 700);
        const minutesName = m => m === 60 ? "hour" : m + " min";
        return { id: "calsetup", name: "Calendar sync", glyph: Icons.calendar, keywords: "icloud apple caldav events autosync",
                 sub: !cs.configured ? "Not connected" : cs.on ? "iCloud, every " + minutesName(cs.minutes) : "iCloud, automatic sync off", children: () => [
            { id: "connect", name: cs.configured ? "Reconnect iCloud…" : "Connect iCloud…", sub: "Apple ID + app-specific password, in a terminal", glyph: Icons.calendar,
              run: () => floatTerm("iCloud", [bin("torii-install"), "calendar"]) },
            { id: "sync", name: "Sync now", glyph: Icons.refresh, keep: true, run: () => { sh([bin("torii-calendar"), "sync"]); say("Syncing the calendar"); } },
            { id: "auto", name: "Automatic sync", glyph: Icons.power, badge: cs.on ? "On" : "Off", keep: true, sub: "In the background, even with the calendar closed",
              run: () => { sh([bin("torii-calendar"), "autosync", cs.on ? "off" : "on"]); refresh(); } },
            { id: "every", name: "Sync every", glyph: Icons.tune, sub: minutesName(cs.minutes), children: () =>
                [1, 5, 15, 30, 60].map(m => ({ id: "m" + m, name: m === 60 ? "1 hour" : m + (m === 1 ? " minute" : " minutes"), badge: cs.minutes === m ? "●" : "", keep: true,
                    run: () => { sh([bin("torii-calendar"), "autosync", "interval", String(m)]); refresh(); } })) } ] };
    }

    // look: bar size, monitor scale, window transparency and blur
    function cfgSlider(id, name, key, min, max, step, value, unit, decimals, sub) {
        return { id: id, name: name, sub: sub || "", glyph: Icons.tune, keywords: "size look appearance",
                 slider: { min: min, max: max, step: step, value: value, unit: unit, decimals: decimals },
                 onSlide: v => sh([bin("torii-config"), "set", key, String(v)]) };
    }
    function hyprSlider(id, name, args, min, max, step, value, unit, decimals, sub) {
        return { id: id, name: name, sub: sub || "", glyph: Icons.tune, keywords: "window look appearance",
                 slider: { min: min, max: max, step: step, value: value, unit: unit, decimals: decimals },
                 onSlide: v => sh([bin("torii-hypr")].concat(args(v))) };
    }
    function appearanceMenu() {
        fMons.ensure(); fHypr.ensure();
        const h = Live.hypr, b = h.blur || { enabled: true, size: 3, passes: 1, vibrancy: 0.17 };
        const blurSet = (k, v) => { const n = Object.assign({}, b, k); return ["blur", String(n.size), String(n.passes), String(n.vibrancy)]; };
        return { id: "appearance", name: "Appearance", glyph: Icons.tune, sub: "Bar size, monitor scale, border, transparency, blur", keywords: "look theme resize scale opacity transparent vibrancy", children: () => [
            cfgSlider("barh", "Bar height", "notch.height", 24, 60, 1, Config.notch.height, " px", 0, "The notch bar at the top"),
            cfgSlider("baro", "Bar opacity", "notch.opacity", 0.3, 1, 0.05, Config.notch.opacity, "", 2),
            { id: "scale", name: "Monitors", glyph: Icons.monitor, sub: "Scale and resolution", onOpen: () => fMons.refresh(), children: () =>
                (fMons.data || []).map(m => ({ id: "m:" + m.name, name: m.name, sub: m.w + "×" + m.h + "@" + m.hz + "  ·  " + m.scale + "×" + (m.desc ? "  ·  " + m.desc : ""), glyph: Icons.monitor, children: () => [
                    { id: "sc", name: "Scale  ·  fits: " + (m.scales.length ? m.scales.map(x => x + "×").join(" ") : "1×"), glyph: Icons.tune,
                      sub: "Possible at " + m.w + "×" + m.h + ": " + (m.scales.length ? m.scales.map(x => x + "×").join(" ") : "1×") + "  ·  it snaps to the nearest",
                      slider: { min: m.scales.length ? m.scales[0] : 1, max: m.scales.length ? m.scales[m.scales.length - 1] : 1, step: 0.05, values: m.scales, value: m.scale, unit: "×", decimals: 2 },
                      onSlide: v => { sh([bin("torii-hypr"), "scale", m.name, String(v)]); later(fMons, 900); } },
                    { id: "res", name: "Resolution", glyph: Icons.monitor, sub: m.w + "×" + m.h + "@" + m.hz, children: () =>
                        (m.modes || []).map(md => ({ id: "r:" + md, name: md.replace("@", " @ ") + " Hz", badge: md === (m.w + "x" + m.h + "@" + m.hz) ? "●" : "", keep: true,
                            run: () => { sh([bin("torii-hypr"), "mode", m.name, md]); later(fMons, 1500); } })) } ] })) },
            hyprSlider("wborder", "Window border width", v => ["border", String(v)], 0, 10, 1, h.border === undefined ? 1 : h.border, " px", 0, "The coloured frame around windows"),
            hyprSlider("wopac", "Window opacity", v => ["opacity", String(v)], 0.3, 1, 0.05, h.opacity === undefined ? 1 : h.opacity, "", 2, "Transparent windows show the blur behind them"),
            { id: "blur", name: "Blur", glyph: Icons.tune, sub: b.enabled === false ? "Off" : b.size + " · " + b.passes + " passes · " + b.vibrancy, children: () => [
                { id: "bon", name: b.enabled === false ? "Turn on" : "Turn off", glyph: Icons.power, badge: b.enabled === false ? "Off" : "On", keep: true,
                  run: () => sh([bin("torii-hypr"), "blur", b.enabled === false ? "on" : "off"]) },
                hyprSlider("bsize", "Size", v => blurSet({ size: v }), 1, 20, 1, b.size, "", 0, "How far the blur spreads"),
                hyprSlider("bpass", "Passes", v => blurSet({ passes: v }), 1, 6, 1, b.passes, "", 0, "More passes: smoother, heavier on the GPU"),
                hyprSlider("bvib", "Vibrancy", v => blurSet({ vibrancy: v }), 0, 1, 0.05, b.vibrancy, "", 2, "How strongly the colours behind are boosted") ] } ] };
    }

    function mouseNode() {
        fHypr.ensure();
        const cur = Live.hypr.sens !== undefined ? Live.hypr.sens : (fHypr.data && fHypr.data.sens !== undefined ? fHypr.data.sens : 0);
        return { id: "mouse", name: "Mouse sensitivity", glyph: Icons.mouse, keywords: "pointer speed cursor",
                 slider: { min: -1, max: 1, step: 0.05, value: cur, unit: "", decimals: 2 },
                 onSlide: v => sh([bin("torii-hypr"), "sensitivity", String(v)]) };
    }

    function file(id, name, path, sub) {
        return { id: id, name: name, sub: sub || path.replace(home, "~"), glyph: Icons.pencil, keywords: "edit config nvim", run: () => edit(path) };
    }
    function configsMenu() {
        const h = home + "/.config/hypr/modules/";
        return { id: "configs", name: "Configs", glyph: Icons.pencil, sub: "Open a config in the editor", children: () => [
            { id: "hypr", name: "Hyprland", glyph: Icons.monitor, sub: "monitors, keybindings, input, …", children: () => [
                file("monitors", "Monitors", h + "monitors.lua"), file("binds", "Keybindings", h + "binds.lua"),
                file("input", "Input", h + "input.lua"), file("autostart", "Autostart", h + "autostart.lua"),
                file("animations", "Animations", h + "animations.lua"), file("decorations", "Decorations", h + "decorations.lua"),
                file("env", "Env", h + "env.lua"), file("layout", "Layout", h + "layout.lua"), file("misc", "Misc", h + "misc.lua"),
                file("rules", "Window rules", h + "rules.lua"), file("permissions", "Permissions", h + "permissions.lua") ] },
            file("shell", "Torii shell", home + "/.config/torii/config.json"),
            file("quicklinks", "Quicklinks", Quicklinks.path),
            file("menu", "Menu order", home + "/.config/torii/menu.json"),
            file("kitty", "Kitty", home + "/.config/kitty/kitty.conf"),
            file("tmux", "Tmux", home + "/.config/tmux/tmux.conf"),
            file("nvim", "Neovim", home + "/.config/nvim/init.lua"),
            file("zsh", "Zsh", home + "/.zshrc"),
            file("shellrc", "Shell aliases", home + "/.config/dotfiles/shellrc") ] };
    }

    function defaultsKind(id, name, glyph, fetch, kind) {
        return { id: id, name: name, glyph: glyph, sub: (fetch.data || []).find(x => x.current)?.name || "", children: () => {
            fetch.ensure();
            const list = (fetch.data || []).map(d => ({
                id: d.id, name: d.name, badge: d.current ? "●" : "", keep: true,
                run: () => { sh([bin("torii-default"), "set", kind, d.id]); fetch.data = (fetch.data || []).map(x => Object.assign({}, x, { current: x.id === d.id })); later(fetch, 800); say(name + ": " + d.name); }
            }));
            return list.length ? list : [{ id: "none", name: "Nothing installed for this", sub: "" }];
        } };
    }
    function defaultsMenu() {
        for (const f of [fBrowser, fEditor, fFiles, fTerminal]) f.ensure();
        return { id: "defaults", name: "Defaults", glyph: Icons.tune, sub: "Browser, editor, files, terminal", children: () => [
            defaultsKind("browser", "Browser", Icons.web, fBrowser, "browser"),
            defaultsKind("editor", "Editor", Icons.pencil, fEditor, "editor"),
            defaultsKind("files", "Files", Icons.folder, fFiles, "files"),
            defaultsKind("terminal", "Terminal", Icons.terminal, fTerminal, "terminal") ] };
    }

    // night light: hyprsunset (GPU) or a warm overlay drawn by the shell, through torii-nightlight
    function night(args) { sh([bin("torii-nightlight")].concat(args)); }
    function nightMenu() {
        const s = Live.night;
        return { id: "nightlight", name: "Night light", glyph: Icons.nightLight, keywords: "blue light warm screen temperature overlay gpu",
                 sub: s.on ? s.temp + " K" + (s.mode === "overlay" ? " overlay" : "") + (s.auto ? "  ·  " + s.from + " → " + s.to : "") : (s.auto ? "Auto " + s.from + " → " + s.to : "Off"),
                 children: () => [
            { id: "toggle", name: s.on ? "Turn off" : "Turn on", glyph: Icons.power, badge: s.on ? "On" : "Off", keep: true, run: () => night(["toggle"]) },
            { id: "method", name: "Method", glyph: Icons.monitor, sub: s.mode === "overlay" ? "Screen overlay" : s.mode === "filter" ? "Screen filter" : "GPU (hyprsunset)", children: () => [
                { id: "gpu", name: "GPU", sub: "hyprsunset changes the colours at the display", badge: s.mode === "gpu" ? "●" : "", keep: true, run: () => night(["mode", "gpu"]) },
                { id: "filter", name: "Screen filter", sub: "A shader on the whole screen: a calm dark red, works on any GPU", badge: s.mode === "filter" ? "●" : "", keep: true, run: () => night(["mode", "filter"]) },
                { id: "overlay", name: "Screen overlay", sub: "A transparent warm layer over every screen, it can only blend", badge: s.mode === "overlay" ? "●" : "", keep: true, run: () => night(["mode", "overlay"]) } ] },
            { id: "temp", name: "Temperature", glyph: Icons.tune, keywords: "kelvin warm slider",
              slider: { min: 2000, max: 6500, step: 100, value: s.temp, unit: " K", decimals: 0 }, onSlide: v => night(["temp", String(v)]) },
            { id: "dim", name: "Dimming", glyph: Icons.tune, keywords: "dark tint darker brightness",
              sub: "Screen filter: how much darker the screen gets (0 = only the colour changes)",
              slider: { min: 0, max: 60, step: 1, value: s.dim === undefined ? 20 : s.dim, unit: " %", decimals: 0 }, onSlide: v => night(["dim", String(v)]) },
            { id: "fade", name: "Fade", glyph: Icons.tune, keywords: "ramp seconds duration slow",
              sub: "How long it takes to fade in or out on a schedule",
              slider: { min: 0, max: 300, step: 5, value: s.fade === undefined ? 30 : s.fade, unit: " s", decimals: 0 }, onSlide: v => night(["fade", String(v)]) },
            { id: "schedule", name: "Schedule", glyph: Icons.nightLight, sub: s.auto ? s.from + " → " + s.to : "Manual", children: () => [
                { id: "manual", name: "Manual", sub: "Only when you switch it", badge: s.auto ? "" : "●", keep: true, run: () => night(["auto", "off"]) },
                { id: "auto", name: "Evening to morning", sub: "20:00 → 07:00", badge: s.auto && s.from === "20:00" && s.to === "07:00" ? "●" : "", keep: true, run: () => night(["auto", "20:00", "07:00"]) },
                { id: "custom", name: "Set times…", sub: "Choose when it turns on and off", keep: true, run: () =>
                    ask("Turn on at (HH:MM)", false, from => ask("Turn off at (HH:MM)", false, to => {
                        if (/^([01]\d|2[0-3]):[0-5]\d$/.test(from) && /^([01]\d|2[0-3]):[0-5]\d$/.test(to)) night(["auto", from, to]);
                        else say("Use the form 21:30");
                    })) } ] } ] };
    }

    // network (Quickshell.Networking, or the mock networks)
    function networkMenu() {
        return { id: "network", name: "Network", glyph: Icons.wifi, keywords: "wifi internet ethernet connect",
                 sub: Net.activeKind === "" ? "Not connected" : Net.activeName + (Net.ip ? "  ·  " + Net.ip : ""),
                 sorted: true, children: () => {
            const out = [];
            if (Net.wiredUp) out.push({ id: "wired", name: Net.wiredName, sub: "Ethernet" + (Net.ip && Net.activeKind === "ethernet" ? "  ·  " + Net.ip : ""), glyph: Icons.ethernet, badge: "●" });
            if (!Net.wifiAvailable) { if (!out.length) out.push({ id: "none", name: "No network adapter", sub: "" }); return out; }
            out.push({ id: "rescan", name: Net.scanning ? "Scanning…" : "Rescan", glyph: Icons.refresh, keep: true, run: () => Net.scan() });
            for (const n of Net.wifiNetworks) {
                out.push({
                    id: "wifi:" + n.name, name: n.name, glyph: Net.strengthGlyph(n), keywords: "wifi wi-fi network",
                    sub: n.connected ? "Connected" : n.known ? "Saved" : Net.secured(n) ? "Secured" : "Open",
                    badge: n.connected ? "●" : "", keep: true,
                    run: () => wifiPrimary(n),
                    children: () => [
                        { id: "go", name: n.connected ? "Disconnect" : "Connect", glyph: Icons.wifi, keep: true, run: () => wifiPrimary(n) },
                        n.known ? { id: "forget", name: "Forget", glyph: Icons.trash, keep: true, run: () => { n.forget(); say("Forgot " + n.name); bump(); } } : null
                    ].filter(x => x !== null)
                });
            }
            return out;
        } };
    }
    property var _wired: ({})
    function wifiPrimary(n) {
        if (n.connected) { n.disconnect(); return; }
        if (!_wired[n.name]) {
            _wired[n.name] = true;
            n.connectionFailed.connect(() => say("Couldn't connect to " + n.name));
        }
        if (Net.secured(n) && !n.known) ask("Password for " + n.name, true, text => { if (text) n.connectWithPsk(text); });
        else n.connect();
    }

    // bluetooth
    function bluetoothMenu() {
        return { id: "bluetooth", name: "Bluetooth", glyph: Icons.bluetooth, keywords: "pair headphones devices",
                 sub: !Bt.available ? "No adapter" : !Bt.powered ? "Off" : Bt.devices.filter(d => d.connected).length + " connected",
                 sorted: true, children: () => {
            if (!Bt.available) return [{ id: "none", name: "No Bluetooth adapter", sub: "" }];
            const out = [
                { id: "power", name: Bt.powered ? "Turn off" : "Turn on", glyph: Icons.power, badge: Bt.powered ? "On" : "Off", keep: true, run: () => Bt.setPowered(!Bt.powered) }
            ];
            if (!Bt.powered) return out;
            out.push({ id: "scan", name: Bt.scanning ? "Stop scanning" : "Scan for new devices", glyph: Icons.refresh, keep: true, run: () => Bt.setScanning(!Bt.scanning) });
            for (const d of Bt.devices) {
                out.push({
                    id: "bt:" + d.address, name: d.name, glyph: Icons[Bt.glyph(d)] || Icons.bluetooth, keywords: "bluetooth device",
                    sub: d.pairing ? "Pairing…" : d.connected ? "Connected" + (d.batteryAvailable ? "  ·  " + Math.round(d.battery * 100) + "%" : "") : d.paired ? "Paired" : "Available",
                    badge: d.connected ? "●" : "", keep: true,
                    run: () => btPrimary(d),
                    children: () => [
                        { id: "go", name: !d.paired ? "Pair" : d.connected ? "Disconnect" : "Connect", glyph: Icons.bluetooth, keep: true, run: () => btPrimary(d) },
                        d.paired ? { id: "forget", name: "Forget", glyph: Icons.trash, keep: true, run: () => { d.forget(); say("Forgot " + d.name); } } : null
                    ].filter(x => x !== null)
                });
            }
            return out;
        } };
    }
    function btPrimary(d) { if (!d.paired) d.pair(); else if (d.connected) d.disconnect(); else d.connect(); }

    // default input / output
    function audioMenu(kind) {
        const out = kind === "output";
        return { id: kind, name: out ? "Output" : "Input", glyph: out ? Icons.speaker : Icons.mic, keywords: "audio sound default device " + (out ? "speakers headphones" : "microphone"),
                 sub: out ? Audio.sinkLabel : Audio.sourceLabel, sorted: true, children: () => {
            const list = (out ? Audio.sinks : Audio.sources).map(d => ({
                id: d.key, name: d.label, badge: d.current ? "●" : "", keep: true,
                run: () => { if (out) Audio.setSink(d.key); else Audio.setSource(d.key); }
            }));
            return list.length ? list : [{ id: "none", name: "No devices", sub: "" }];
        } };
    }
}
