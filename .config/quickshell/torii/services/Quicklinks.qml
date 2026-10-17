pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import QtQuick

// Quicklinks from one hand-edited file (hot-reloaded), a list of
//   { "keyword": "yt", "name": "YouTube", "url": "https://www.youtube.com/results?search_query={input}", "icon": "youtube" }
// `yt cats` searches ({input} is replaced), `yt` alone opens the site. Without {input} the url is opened as it is.
// `icon` is an icon-theme name, a glyph or an absolute image path; without one the site's own icon is used
// (torii-favicon fetches it into ~/.cache/torii/favicons), and until that is there the link glyph.
// The old map form {"yt": "https://...{q}"} still works.
Singleton {
    id: root

    property var links: ({})
    property int iconRev: 0          // bumps when new site icons arrive, so images load again
    readonly property string path: Config.expand(Config.quicklinks)

    // normalise both file forms to { keyword: {url, name, icon, home} }
    function parse(raw) {
        const out = {};
        const add = (k, v) => {
            const o = typeof v === "string" ? { url: v } : v;
            if (k && o && o.url) out[String(k).toLowerCase()] = Object.assign({}, o, { url: o.url.replace("{input}", "{q}") });
        };
        if (Array.isArray(raw)) raw.forEach(e => add(e.keyword, e));
        else for (const k in raw) add(k, raw[k]);
        return out;
    }

    function entryFor(keyword) {
        const o = links[keyword.toLowerCase()];
        if (o === undefined) return null;
        const host = (/^[a-z]+:\/\/([^\/?#]+)/i.exec(o.url) || [])[1] || o.url;
        const origin = (/^[a-z]+:\/\/[^\/?#]+/i.exec(o.url) || [o.url])[0];
        return { keyword: keyword.toLowerCase(), url: o.url, name: o.name || host.replace(/^www\./, ""),
                 home: o.home || (o.url.indexOf("{q}") >= 0 ? origin : o.url), host: host.replace(/^www\./, ""),
                 icon: o.icon || (Config.home + "/.cache/torii/favicons/" + host.replace(/^www\./, "") + ".png") };
    }

    // "yt cats" -> { title, sub, url } ; "git" -> opens its own URL ; null when the first word is no keyword
    function resolve(query) {
        const m = /^(\S+)(?:\s+(.*))?$/.exec(query.trim());
        if (!m) return null;
        const e = entryFor(m[1]);
        if (!e) return null;
        const text = (m[2] || "").trim();
        if (text === "" || e.url.indexOf("{q}") < 0)
            return { title: e.name, sub: e.keyword + "  ·  " + e.home, url: text === "" ? e.home : e.url, keyword: e.keyword, icon: e.icon };
        return { title: text, sub: e.name + "  ·  search", url: e.url.replace("{q}", encodeURIComponent(text)), keyword: e.keyword, icon: e.icon };
    }

    FileView {
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.links = root.parse(JSON.parse(text())); } catch (e) { console.warn("quicklinks: invalid JSON in", root.path); }
            favicons.running = false;
            favicons.running = true;
        }
    }

    // site icons for the links that have none (the ones already fetched are skipped)
    Process {
        id: favicons
        command: [Config.home + "/.config/torii/bin/torii-favicon", "links", root.path]
        stdout: StdioCollector { onStreamFinished: if (parseInt(text) > 0) root.iconRev++ }
    }
}
