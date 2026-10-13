pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import QtQuick

// Keyword -> URL template, from one hand-edited file (hot-reloaded):
//   "yt": "https://www.youtube.com/results?search_query={q}"     `yt cats` searches, `yt` opens youtube.com
//   "git": "https://github.com/equa-tory"                         `git` opens it (no {q})
//   "x": { "url": "https://x.com/search?q={q}", "name": "X", "home": "https://x.com" }   optional long form
Singleton {
    id: root

    property var links: ({})
    readonly property string path: Config.expand(Config.quicklinks)

    function entryFor(keyword) {
        const v = links[keyword.toLowerCase()];
        if (v === undefined) return null;
        const o = typeof v === "string" ? { url: v } : v;
        if (!o.url) return null;
        const host = (/^[a-z]+:\/\/([^\/?#]+)/i.exec(o.url) || [])[1] || o.url;
        const origin = (/^[a-z]+:\/\/[^\/?#]+/i.exec(o.url) || [o.url])[0];
        return { keyword: keyword.toLowerCase(), url: o.url, name: o.name || host.replace(/^www\./, ""),
                 home: o.home || (o.url.indexOf("{q}") >= 0 ? origin : o.url), host: host.replace(/^www\./, "") };
    }

    // "yt cats" -> { title, sub, url } ; "git" -> opens its own URL ; null when the first word is no keyword
    function resolve(query) {
        const m = /^(\S+)(?:\s+(.*))?$/.exec(query.trim());
        if (!m) return null;
        const e = entryFor(m[1]);
        if (!e) return null;
        const text = (m[2] || "").trim();
        if (text === "" || e.url.indexOf("{q}") < 0)
            return { title: e.name, sub: e.keyword + "  ·  " + e.home, url: text === "" ? e.home : e.url, keyword: e.keyword };
        return { title: text, sub: e.name + "  ·  search", url: e.url.replace("{q}", encodeURIComponent(text)), keyword: e.keyword };
    }

    FileView {
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.links = JSON.parse(text()); } catch (e) { console.warn("quicklinks: invalid JSON in", root.path); }
        }
    }
}
