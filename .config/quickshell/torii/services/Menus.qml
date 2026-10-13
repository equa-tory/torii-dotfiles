pragma Singleton
import qs
import qs.widgets
import "../widgets/fuzzy.js" as Fuzzy
import Quickshell
import Quickshell.Io
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
    Connections { target: Audio; function onSinksChanged() { root.bump(); } function onSourcesChanged() { root.bump(); } }

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
    JsonFetch { id: fNight;    command: [root.bin("torii-nightlight"), "status"];         onDataChanged: root.bump() }
    JsonFetch { id: fTrig;     command: [root.bin("torii-trigger"), "status"];            onDataChanged: root.bump() }
    JsonFetch { id: fEmoji;    command: [root.bin("torii-emoji"), "list"];
                onDataChanged: { root.emojiNodes = (data || []).map(e => ({ id: "e:" + e.c, name: e.n, sub: e.g, glyph: e.c, run: () => app([root.bin("torii-emoji"), "copy", e.c]) }));
                    root.bump(); } }
    JsonFetch { id: fTrans;    command: [root.bin("torii-transcode"), "list"];            onDataChanged: root.bump() }
    property var emojiNodes: []
    readonly property var allFetch: [fBrowser, fFiles, fTerminal, fEditor, fNight, fTrig, fEmoji, fTrans]
    Connections { target: Theme; function onModeChanged() { root.bump(); } }
    Connections { target: Config; function onNotchChanged() { fTrig.stale(); } }
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

    function rootNodes() { return ordered("", [appsMenu(), triggerMenu(), setupMenu()]); }
    function isMenu(n) { return n.children !== undefined; }

    // ---- search: every node below `scope` (everything when null), with the path it was found under
    function search(scope, query) {
        const q = query.trim().toLowerCase();
        const entries = [];
        function walk(node, trail, depth) {
            for (const c of childrenOf(node)) {
                entries.push({ node: c, trail: trail });
                if (isMenu(c) && !c.noSearch && depth < 4) walk(c, c.flat ? trail : trail.concat(c.name), depth + 1);
            }
        }
        walk(scope, scope ? [scope.name] : [], 0);
        const scored = [];
        for (const e of entries) {
            const s = Fuzzy.scoreFields(q, [
                { text: e.node.name, weight: 1 },
                { text: e.trail.join(" "), weight: 0.45 },
                { text: e.node.keywords || "", weight: 0.6 },
                { text: e.node.sub || "", weight: 0.3 }
            ]);
            if (s >= 0) scored.push({ e: e, s: s - (isMenu(e.node) && !e.node.flat ? 0 : 0) });
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
    function toggle(fetch, args, keep) { sh(args); later(fetch, 500); }
    function human(n) { return n > 1048576 ? (n / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(n / 1024)) + " KB"; }

    function triggerMenu() {
        fTrig.ensure();
        const t = fTrig.data || { automove: {}, hypr: {}, shape: "attached" };
        const hyprBin = bin("torii-hypr");
        return { id: "trigger", name: "Trigger", glyph: Icons.flash, sub: "Capture, convert, remind, switches", children: () => [
            captureMenu(t),
            transcodeMenu(),
            { id: "emoji", name: "Emoji", glyph: Icons.emoji, sub: "Copy and type an emoji", noSearch: true, sorted: true,
              children: () => { fEmoji.ensure(); return emojiNodes; } },
            { id: "reminder", name: "Reminder", glyph: Icons.timer, sub: "In some minutes, with a message", keywords: "timer alarm notify", keep: true,
              run: () => ask("Remind me in (minutes)", false, m => {
                  const n = parseFloat(String(m).replace(",", "."));
                  if (!(n > 0)) { say("Type a number of minutes, like 25"); return; }
                  ask("Remind me about…", false, msg => {
                      sh(["systemd-run", "--user", "--collect", "--unit=torii-remind-" + Date.now(), "--on-active=" + Math.round(n * 60) + "s",
                          "notify-send", "-a", "torii", "-u", "critical", "Reminder", msg || "Time is up"]);
                      Panels.close();
                  });
              }) },
            { id: "automove", name: "File auto mover", glyph: Icons.folderMove, keywords: "downloads move inbox photos",
              sub: t.automove.enabled ? "Moving new files to " + (t.automove.to || "").replace(home, "~") : "Downloads → " + (t.automove.to || "").replace(home, "~"),
              badge: t.automove.enabled ? "On" : "Off", keep: true, run: () => toggle(fTrig, [bin("torii-automove"), t.automove.enabled ? "off" : "on"]) },
            { id: "mic", name: "Mute microphone", glyph: Audio.sourceMuted ? Icons.micOff : Icons.mic, keywords: "input mic mute",
              badge: Audio.sourceMuted ? "Muted" : "", keep: true, run: () => { Audio.toggleSourceMute(); bump(); } },
            { id: "dnd", name: "Do not disturb", glyph: t.dnd ? Icons.bellOff : Icons.bell, keywords: "notifications silence",
              sub: "Notifications", badge: t.dnd ? "On" : "Off", keep: true, run: () => toggle(fTrig, ["swaync-client", "-d", "-sw"]) },
            { id: "dark", name: "Dark mode", glyph: Icons.themeDark, keywords: "light theme appearance",
              badge: Theme.mode === "dark" ? "On" : "Off", keep: true, run: () => sh([bin("torii-theme"), "mode", "toggle"]) },
            { id: "shape", name: "Menu bar shape", glyph: Icons.layout, keywords: "notch floating attached",
              sub: t.shape === "floating" ? "Floating" : "Attached", badge: t.shape === "floating" ? "Floating" : "Attached", keep: true,
              run: () => { sh([bin("torii-config"), "set", "notch.shape", t.shape === "floating" ? '"attached"' : '"floating"']); later(fTrig, 500); } },
            { id: "layout", name: "Workspace layout", glyph: Icons.layout, sub: t.hypr.layout || "dwindle", keywords: "tiling dwindle master scrolling", children: () =>
                [["dwindle", "Split in halves, newest window splits the focused one"], ["master", "One big window and a stack"], ["scrolling", "Columns that scroll sideways"]].map(l => ({
                    id: l[0], name: l[0].charAt(0).toUpperCase() + l[0].slice(1), sub: l[1], badge: (t.hypr.layout || "dwindle") === l[0] ? "●" : "", keep: true,
                    run: () => { sh([hyprBin, "layout", l[0]]); later(fTrig, 500); } })) },
            { id: "gaps", name: "Window gaps", glyph: Icons.layout, sub: (t.hypr.gaps_in ?? 8) + " / " + (t.hypr.gaps_out ?? 20), keywords: "spacing margin", children: () =>
                [["None", 0, 0], ["Tight", 2, 5], ["Small", 4, 10], ["Default", 8, 20], ["Large", 12, 32]].map(g => ({
                    id: "g" + g[0], name: g[0], sub: g[1] + " inside, " + g[2] + " outside", badge: (t.hypr.gaps_out ?? 20) === g[2] ? "●" : "", keep: true,
                    run: () => { sh([hyprBin, "gaps", String(g[1]), String(g[2])]); later(fTrig, 500); } })) },
            { id: "speed", name: "Speed test", glyph: Icons.speed, sub: "Network or disk, result as a notification", children: () => [
                { id: "net", name: "Network", sub: "Download, upload, latency", glyph: Icons.wifi, run: () => app([bin("torii-speed"), "net"]) },
                { id: "disk", name: "Disk", sub: "Write and read 512 MB in your home folder", glyph: Icons.folder, run: () => app([bin("torii-speed"), "disk"]) } ] }
        ] };
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
                 children: () => [configsMenu(), defaultsMenu(), nightMenu(), networkMenu(), bluetoothMenu(), audioMenu("input"), audioMenu("output")] };
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
                run: () => { sh([bin("torii-default"), "set", kind, d.id]); later(fetch, 500); say(name + ": " + d.name); }
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

    // night light (hyprsunset through torii-nightlight)
    function night(args) { sh([bin("torii-nightlight")].concat(args)); later(fNight, 700); }
    function nightMenu() {
        fNight.ensure();
        const s = fNight.data || { on: false, temp: 4000, auto: false, from: "20:00", to: "07:00" };
        return { id: "nightlight", name: "Night light", glyph: Icons.nightLight, keywords: "blue light warm screen temperature",
                 sub: s.on ? s.temp + " K" + (s.auto ? "  ·  " + s.from + " → " + s.to : "") : (s.auto ? "Auto " + s.from + " → " + s.to : "Off"),
                 children: () => [
            { id: "toggle", name: s.on ? "Turn off" : "Turn on", glyph: Icons.power, badge: s.on ? "On" : "Off", keep: true, run: () => night(["toggle"]) },
            { id: "temp", name: "Temperature", glyph: Icons.tune, sub: s.temp + " K", children: () =>
                [2500, 3000, 3500, 4000, 4500, 5000, 5500, 6000].map(k => ({
                    id: "t" + k, name: k + " K", sub: k <= 3000 ? "very warm" : k <= 4000 ? "warm" : k <= 5000 ? "mild" : "slight", badge: s.temp === k ? "●" : "", keep: true,
                    run: () => night(["temp", String(k)]) })) },
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
