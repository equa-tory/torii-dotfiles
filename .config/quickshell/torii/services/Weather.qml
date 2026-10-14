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
    property real wind: 0               // km/h
    property var hourly: []             // next hours: { hour, temp, code, day }
    property var daily: []              // { name, max, min, code }
    property string city: ""
    property double updated: 0          // ms since epoch of the last successful fetch

    // resolved place: config lat/lon win, then a city name from config, then the one in the system timezone
    property real lat: 0
    property real lon: 0
    readonly property bool located: lat !== 0 || lon !== 0

    readonly property bool available: code >= 0
    readonly property bool stale: Date.now() - updated > Config.weather.refreshMin * 60000 * 2.5
    readonly property bool windy: wind >= 30
    readonly property string glyph: glyphFor(code, isDay, wind)

    function glyphFor(c, day, w) {
        const g = (cp) => String.fromCodePoint(cp);
        if (c <= 3 && w >= 30) return g(c === 3 ? 0xF059E : 0xF059D);     // windy, windy-variant (cloudy)
        if (c === 0) return day ? g(0xF0599) : g(0xF0594);
        if (c === 1 || c === 2) return day ? g(0xF0595) : g(0xF0F31);
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

    function describe(c) {
        if (c === 0) return "Clear";
        if (c <= 2) return "Partly cloudy";
        if (c === 3) return "Overcast";
        if (c === 45 || c === 48) return "Fog";
        if (c >= 51 && c <= 57) return "Drizzle";
        if (c >= 61 && c <= 67) return "Rain";
        if (c >= 71 && c <= 77) return "Snow";
        if (c >= 80 && c <= 82) return "Showers";
        if (c === 85 || c === 86) return "Snow showers";
        if (c >= 95) return "Thunderstorm";
        return "";
    }

    function resolveLocation() {
        if (Config.weather.lat !== 0 || Config.weather.lon !== 0) {
            lat = Config.weather.lat; lon = Config.weather.lon;
            city = Config.weather.location || "";
            fetch();
            return;
        }
        tz.running = true;
    }

    function geocode(name, zone) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) return;
            try {
                const r = (JSON.parse(xhr.responseText).results || []);
                const hit = r.find(x => x.timezone === zone) || r[0];
                if (!hit) return;
                root.lat = hit.latitude; root.lon = hit.longitude; root.city = hit.name;
                place.setText(JSON.stringify({ key: root.placeKey(), lat: hit.latitude, lon: hit.longitude, city: hit.name }));
                root.fetch();
            } catch (e) { console.warn("weather: geocoding failed", e); }
        };
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=8&name=" + encodeURIComponent(name));
        xhr.send();
    }

    property string zone: ""
    function placeKey() { return Config.weather.location || zone; }

    // "Europe/Moscow" -> "Moscow", "America/New_York" -> "New York"
    Process {
        id: tz
        command: ["timedatectl", "show", "-p", "Timezone", "--value"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.zone = text.trim();
                const name = Config.weather.location || root.zone.split("/").pop().replace(/_/g, " ");
                if (name === "" || (root.located && place.key === root.placeKey())) { root.fetch(); return; }
                root.geocode(name, Config.weather.location ? "" : root.zone);
            }
        }
    }

    function fetch() {
        if (!located) return;
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
                  + "&current=temperature_2m,weather_code,is_day,wind_speed_10m"
                  + "&hourly=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min"
                  + "&forecast_days=6&timezone=auto";
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status !== 200)
                return;
            try {
                root.apply(JSON.parse(xhr.responseText));
                root.updated = Date.now();
                cache.setText(JSON.stringify({ temp: root.temp, code: root.code, isDay: root.isDay, wind: root.wind,
                                               hourly: root.hourly, daily: root.daily, updated: root.updated }));
            } catch (e) {
                console.warn("weather: bad response", e);
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function apply(d) {
        const cur = d.current;
        temp = cur.temperature_2m;
        code = cur.weather_code;
        isDay = cur.is_day === 1;
        wind = cur.wind_speed_10m || 0;
        const h = d.hourly, now = cur.time;
        let i = h.time.findIndex(t => t >= now);
        if (i < 0) i = 0;
        const hours = [];
        for (let k = i; k < Math.min(h.time.length, i + 24); k += 3)
            hours.push({ hour: h.time[k].slice(11, 16), temp: h.temperature_2m[k], code: h.weather_code[k], day: true });
        hourly = hours;
        const dl = d.daily, days = [];
        for (let k = 0; k < dl.time.length; k++) {
            const dt = new Date(dl.time[k] + "T12:00:00");
            days.push({ name: k === 0 ? "Today" : Qt.locale().dayName(dt.getDay(), Locale.ShortFormat),
                        max: dl.temperature_2m_max[k], min: dl.temperature_2m_min[k], code: dl.weather_code[k] });
        }
        daily = days;
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
                root.wind = d.wind || 0;
                root.hourly = d.hourly || [];
                root.daily = d.daily || [];
                root.updated = d.updated;
            } catch (e) {}
        }
    }

    // geocoded place, cached so the lookup happens once per timezone
    FileView {
        id: place
        path: Config.stateDir + "/weather-place.json"
        printErrors: false
        property string key: ""
        onLoaded: {
            try {
                const d = JSON.parse(text());
                key = d.key; root.lat = d.lat; root.lon = d.lon; root.city = d.city;
            } catch (e) {}
            root.resolveLocation();
        }
        onLoadFailed: root.resolveLocation()
    }

    Timer {
        interval: Math.max(1, Config.weather.refreshMin) * 60000
        running: true
        repeat: true
        onTriggered: root.fetch()
    }

    // a changed location should show up right away
    Connections {
        target: Config.weather
        function onLatChanged() { root.resolveLocation(); }
        function onLonChanged() { root.resolveLocation(); }
        function onLocationChanged() { place.key = ""; root.lat = 0; root.lon = 0; root.resolveLocation(); }
    }
}
