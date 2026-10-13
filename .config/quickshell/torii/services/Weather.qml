pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import QtQuick

// Open-Meteo current weather (no API key). Refreshes every refreshMin minutes and when the cache is stale,
// keeps the last value in the state dir so the notch still shows something offline.
Singleton {
    id: root

    property real temp: 0
    property int code: -1
    property bool isDay: true
    property double updated: 0          // ms since epoch of the last successful fetch

    readonly property bool available: code >= 0
    readonly property bool stale: Date.now() - updated > Config.weather.refreshMin * 60000 * 2.5

    readonly property string glyph: {
        const g = (cp) => String.fromCodePoint(cp);
        const c = code;
        if (c === 0) return isDay ? g(0xF0599) : g(0xF0594);
        if (c === 1 || c === 2) return isDay ? g(0xF0595) : g(0xF0F31);
        if (c === 3) return g(0xF0590);
        if (c === 45 || c === 48) return g(0xF0591);
        if (c >= 51 && c <= 57) return g(0xF0F33);
        if (c === 65 || c === 82) return g(0xF0596);
        if (c === 66 || c === 67) return g(0xF067F);
        if (c === 61 || c === 63 || c === 80 || c === 81) return g(0xF0597);
        if (c === 75 || c === 86) return g(0xF0F36);
        if (c === 71 || c === 73 || c === 77 || c === 85) return g(0xF0598);
        if (c === 96 || c === 99) return g(0xF0592);
        if (c >= 95) return g(0xF0593);
        return g(0xF0590);
    }

    function fetch() {
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + Config.weather.lat
                  + "&longitude=" + Config.weather.lon
                  + "&current=temperature_2m,weather_code,is_day";
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status !== 200)
                return;
            try {
                const cur = JSON.parse(xhr.responseText).current;
                root.temp = cur.temperature_2m;
                root.code = cur.weather_code;
                root.isDay = cur.is_day === 1;
                root.updated = Date.now();
                cache.setText(JSON.stringify({ temp: root.temp, code: root.code, isDay: root.isDay, updated: root.updated }));
            } catch (e) {
                console.warn("weather: bad response", e);
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    FileView {
        id: cache
        path: Config.stateDir + "/weather.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.temp = d.temp;
                root.code = d.code;
                root.isDay = d.isDay;
                root.updated = d.updated;
            } catch (e) {}
        }
    }

    Timer {
        interval: Math.max(1, Config.weather.refreshMin) * 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetch()
    }

    // a changed location should show up right away
    Connections {
        target: Config.weather
        function onLatChanged() { root.fetch(); }
        function onLonChanged() { root.fetch(); }
    }
}
