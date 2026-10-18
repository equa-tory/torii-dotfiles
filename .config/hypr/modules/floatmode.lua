---------------------
---- FLOAT MODE  ----
---------------------
-- Alt+Shift+N switches the whole desktop between tiled and floating windows (like Windows / macOS).
-- Every window remembers where it floated: its size and place come back, animated, when you float again.
-- Windows that were floating on their own (dialogs, app rules, floated by hand) stay floating in tiled mode.
-- The chosen mode survives restarts (~/.local/state/torii/floatmode.lua, also read by the shell).

local STATE = os.getenv("HOME") .. "/.local/state/torii/floatmode.lua"

-- a config reload runs this file again: drop the event handlers of the previous run, or they would all fire (with their own old state)
for _, sub in ipairs(torii_float_subs or {}) do pcall(function() sub:remove() end) end
torii_float_subs = {}
local function on(event, fn) torii_float_subs[#torii_float_subs + 1] = hl.on(event, fn) end

local mode = "tile"           -- "tile" | "float"
local class_geo = {}          -- class -> {x, y, w, h}: where the last window of that app floated
local geo = {}                -- address -> {x, y, w, h}: where this window floated
local placed = {}             -- address -> true: a remembered app's window that has been put in place
local was_floating = {}       -- address -> true: floating before float mode took over (stays floating in tile mode)

do
    local ok, saved = pcall(dofile, STATE)
    if ok and type(saved) == "table" then
        mode = saved.mode == "float" and "float" or "tile"
        class_geo = type(saved.geo) == "table" and saved.geo or {}
    end
end

-- web apps (Telegram, Discord: Helium --app windows) stay tiled in float mode; an app rule with "float" still floats one
local function stays_tiled(w) return w.class ~= nil and w.class:match("^chrome%-.+%-Default$") ~= nil end

local function save()
    local f = io.open(STATE, "w")
    if not f then return end
    f:write(string.format("return { mode = %q, geo = {\n", mode))
    for class, g in pairs(class_geo) do
        f:write(string.format("  [%q] = { x = %d, y = %d, w = %d, h = %d },\n", class, g.x, g.y, g.w, g.h))
    end
    f:write("} }\n")
    f:close()
end

-- apps with "Remember position and size" (Setup > App rules; torii-rules sets the torii_remember_apps table)
local function remembered(class) return type(torii_remember_apps) == "table" and torii_remember_apps[class] == true end

local function xy(v, a, b) return v[a] or v[b] or 0 end

local function remember(w)
    if not w.floating then return end
    local g = { x = xy(w.at, "x", 1), y = xy(w.at, "y", 2), w = xy(w.size, "x", 1), h = xy(w.size, "y", 2) }
    geo[w.address] = g
    if w.class and w.class ~= "" then class_geo[w.class] = g end
end

local cascade = 0
-- where a window floats: its own memory, then its app's, then a cascade of 62% x 68% windows on its monitor
local function target(w)
    local g = geo[w.address]
    if g then return g end
    g = class_geo[w.class]
    if g and remembered(w.class) then return g end          -- exactly where it was
    if g then                                   -- the app's usual place, nudged so windows of one app do not stack exactly
        cascade = (cascade + 1) % 8
        local mon = w.monitor or hl.get_active_monitor()
        local mw = (mon and mon.width or 1920) / ((mon and mon.scale) or 1)
        local mh = (mon and mon.height or 1080) / ((mon and mon.scale) or 1)
        local mx, my = mon and mon.x or 0, mon and mon.y or 0
        local x = math.max(mx, math.min(g.x + cascade * 28, mx + mw - g.w))      -- keep it on the screen
        local y = math.max(my + 40, math.min(g.y + cascade * 22, my + mh - g.h))
        return { x = x, y = y, w = g.w, h = g.h }
    end
    local mon = w.monitor or hl.get_active_monitor()
    local mw = (mon and mon.width or 1920) / ((mon and mon.scale) or 1)
    local mh = (mon and mon.height or 1080) / ((mon and mon.scale) or 1)
    local mx, my = mon and mon.x or 0, mon and mon.y or 0
    local width, height = math.floor(mw * 0.62), math.floor(mh * 0.68)
    cascade = (cascade + 1) % 8
    return {
        x = mx + math.floor((mw - width) / 2) + (cascade - 4) * 28,
        y = my + math.floor((mh - height) / 2) + (cascade - 4) * 22,
        w = width, h = height,
    }
end

local function float_to(w, g)
    if not w.floating then hl.dispatch(hl.dsp.window.float({ action = "set", window = w })) end
    hl.dispatch(hl.dsp.window.resize({ x = g.w, y = g.h, exact = true, window = w }))
    hl.dispatch(hl.dsp.window.move({ x = g.x, y = g.y, exact = true, window = w }))
end

local function minimized(w)
    return w.workspace and w.workspace.name and w.workspace.name:find("^special:minimized") ~= nil
end

local function every_window(fn)
    for _, w in ipairs(hl.get_windows()) do
        if w.mapped and not w.hidden and w.fullscreen == 0 then fn(w) end
    end
end

local function set_mode(m)
    if m == mode then return end
    mode = m
    if mode == "float" then
        every_window(function(w)
            if w.floating then
                was_floating[w.address] = true
            elseif not stays_tiled(w) then
                float_to(w, target(w))
            end
        end)
    else
        every_window(function(w)
            if w.floating then
                remember(w)
                if not was_floating[w.address] then
                    hl.dispatch(hl.dsp.window.float({ action = "unset", window = w }))
                end
            end
        end)
    end
    save()
end

hl.bind("ALT + SHIFT + N", function() set_mode(mode == "float" and "tile" or "float") end)

-- windows opened while floating: float them where they were last
on("window.open", function(w)
    if remembered(w.class) then
        -- a remembered app's window is floating (the rule says so) and goes where it was; Hyprland centres a new floating
        -- window once it is mapped, so it is put back a moment later. Only then does it count as "placed": until then
        -- the focus snapshot below must not take its fresh, centred position as the app's remembered one.
        local g = class_geo[w.class]
        local addr = w.address
        if g then float_to(w, g) end
        hl.timer(function()
            if g then
                os.execute(string.format(
                    "hyprctl --batch 'dispatch hl.dsp.window.resize({ x = %d, y = %d, exact = true, window = \"address:%s\" }) ; dispatch hl.dsp.window.move({ x = %d, y = %d, exact = true, window = \"address:%s\" })' >/dev/null 2>&1 &",
                    g.w, g.h, addr, g.x, g.y, addr))
            end
            placed[addr] = true
        end, { timeout = 500, type = "oneshot" })
        return
    end
    if mode ~= "float" or w.floating or stays_tiled(w) then return end
    float_to(w, target(w))
end)

-- remembered apps: note where their windows are whenever focus moves, so a move or resize is not lost (also at close)
on("window.active", function()
    local changed = false
    for _, w in ipairs(hl.get_windows()) do
        if w.floating and w.mapped and remembered(w.class) and placed[w.address] then
            local g = class_geo[w.class]
            local x, y, ww, hh = xy(w.at, "x", 1), xy(w.at, "y", 2), xy(w.size, "x", 1), xy(w.size, "y", 2)
            if not g or g.x ~= x or g.y ~= y or g.w ~= ww or g.h ~= hh then
                class_geo[w.class] = { x = x, y = y, w = ww, h = hh }
                changed = true
            end
        end
    end
    if changed then save() end
end)

-- "Use how it is now" (torii-rules snapshot): keep the place and size of this app's floating windows right away
function torii_remember_class_now(class)
    for _, w in ipairs(hl.get_windows()) do
        if w.class == class and w.floating and w.mapped then remember(w) end
    end
    save()
end

-- remember where a floating window was when it goes away, so the next one of that app comes back there
on("window.close", function(w)
    if w and w.floating and (not remembered(w.class) or placed[w.address]) then remember(w) end
    if w then placed[w.address] = nil end
    if w then geo[w.address], was_floating[w.address] = nil, nil end
    save()
end)

-- Alt+Shift+arrows in float mode: half of the screen (still floating), up fills it, down gives back the old place.
-- "Fills" means what a lone tiled window gets: inside the bar's reserved strip and the outer gaps (general.gaps_out),
-- and below the title bar, so it follows the notch height and the gap settings.
local before_snap = {}      -- address -> geometry before the first snap / maximise

local function bar_height()
    local ok, b = pcall(dofile, os.getenv("HOME") .. "/.local/state/torii/bars.lua")
    return (ok and type(b) == "table" and tonumber(b.height)) or 28
end

local function area_of(mon)
    local r = mon.reserved or {}
    local sc = mon.scale or 1
    local go = hl.get_config("general.gaps_out")
    if type(go) ~= "table" then go = { top = 20, left = 20, bottom = 20, right = 20 } end
    local top = (r.top or 0) + (go.top or 0) + bar_height()
    local left = (r.left or 0) + (go.left or 0)
    return {
        x = mon.x + left,
        y = mon.y + top,
        w = mon.width / sc - left - (r.right or 0) - (go.right or 0),
        h = mon.height / sc - top - (r.bottom or 0) - (go.bottom or 0),
        gap = go.left or 8,
    }
end

-- the monitor the window is on by where it is (w.monitor lags behind right after the window was moved to another monitor)
local function monitor_of(w)
    local cx, cy = xy(w.at, "x", 1) + xy(w.size, "x", 1) / 2, xy(w.at, "y", 2) + xy(w.size, "y", 2) / 2
    for _, m in ipairs(hl.get_monitors()) do
        local sc = m.scale or 1
        if cx >= m.x and cx < m.x + m.width / sc and cy >= m.y and cy < m.y + m.height / sc then return m end
    end
    return w.monitor or hl.get_active_monitor()
end

local function work_area(w)
    return area_of(monitor_of(w))
end

-- the nearest monitor on that side (left / right) of mon, or nil
local function neighbour(mon, dir)
    local best, dist
    local edge = mon.x + mon.width / (mon.scale or 1)
    for _, m in ipairs(hl.get_monitors()) do
        if m.name ~= mon.name then
            local d = dir == "right" and (m.x - edge) or (mon.x - (m.x + m.width / (m.scale or 1)))
            if d >= -2 and (not dist or d < dist) then best, dist = m, d end
        end
    end
    return best
end

local function place(w, g)
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(g.w), y = math.floor(g.h), exact = true, window = w }))
    hl.dispatch(hl.dsp.window.move({ x = math.floor(g.x), y = math.floor(g.y), exact = true, window = w }))
end

local function remember_before(w)
    if not before_snap[w.address] then
        before_snap[w.address] = { x = xy(w.at, "x", 1), y = xy(w.at, "y", 2), w = xy(w.size, "x", 1), h = xy(w.size, "y", 2) }
    end
end

function torii_float_snap(dir)
    if mode ~= "float" then return false end
    local w = hl.get_active_window()
    if not w or not w.floating then return false end
    local mon = monitor_of(w)
    local a = work_area(w)
    local half = (a.w - a.gap) / 2
    local g
    if dir == "left" then g = { x = a.x, y = a.y, w = half, h = a.h }
    elseif dir == "right" then g = { x = a.x + a.w - half, y = a.y, w = half, h = a.h } end
    -- already on that half: the next press sends it to the monitor on that side, onto the half next to the edge it came from
    if g and (dir == "left" or dir == "right") then
        local function near(v, t) return math.abs(v - t) <= 6 end
        if near(xy(w.at, "x", 1), g.x) and near(xy(w.at, "y", 2), g.y) and near(xy(w.size, "x", 1), g.w) then
            local n = neighbour(mon, dir)
            if n then
                local a2 = area_of(n)
                local half2 = (a2.w - a2.gap) / 2
                place(w, { x = dir == "left" and (a2.x + a2.w - half2) or a2.x, y = a2.y, w = half2, h = a2.h })
            end
            return true
        end
    end
    if dir == "up" then g = { x = a.x, y = a.y, w = a.w, h = a.h }
    elseif dir == "down" then
        g = before_snap[w.address]
        before_snap[w.address] = nil
        if not g then return true end
        place(w, g)
        return true
    elseif not g then return false end
    remember_before(w)
    place(w, g)
    return true
end

-- the maximise button / double-click on a floating window: fill the work area, again to go back (true = handled here)
function torii_float_maximize()
    local w = hl.get_active_window()
    if not w or not w.floating then return false end
    local old = before_snap[w.address]
    if old then
        before_snap[w.address] = nil
        place(w, old)
    else
        local a = work_area(w)
        remember_before(w)
        place(w, a)
    end
    return true
end


-- Ctrl+Alt+Shift+Up: the focused window takes BIG_WINDOW_PERCENT of the work area, centred (again: back to how it was).
-- Ctrl+Alt+Shift+Down: centre the focused window. Both float a tiled window first.
-- The percentage: Setup > Windows > Big window size (kept in ~/.local/state/torii/windowsize.lua), or change the default here.
local BIG_WINDOW_PERCENT = 70

local function big_percent()
    local ok, t = pcall(dofile, os.getenv("HOME") .. "/.local/state/torii/windowsize.lua")
    local p = ok and type(t) == "table" and tonumber(t.percent) or BIG_WINDOW_PERCENT
    return math.max(30, math.min(100, p)) / 100
end

local function ensure_floating(w)
    if not w.floating then hl.dispatch(hl.dsp.window.float({ action = "set", window = w })) end
end

function torii_window_big()
    local w = hl.get_active_window()
    if not w then return end
    local old = before_snap[w.address]
    if old and w.floating then
        before_snap[w.address] = nil
        place(w, old)
        return
    end
    local a = work_area(w)
    local f = big_percent()
    local width, height = a.w * f, a.h * f
    ensure_floating(w)
    remember_before(w)
    place(w, { x = a.x + (a.w - width) / 2, y = a.y + (a.h - height) / 2, w = width, h = height })
end

function torii_window_center()
    local w = hl.get_active_window()
    if not w then return end
    ensure_floating(w)
    local a = work_area(w)
    local ww, wh = xy(w.size, "x", 1), xy(w.size, "y", 2)
    ww, wh = math.min(ww, a.w), math.min(wh, a.h)
    place(w, { x = a.x + (a.w - ww) / 2, y = a.y + (a.h - wh) / 2, w = ww, h = wh })
end

-- the launcher (torii-hypr float) toggles it too
function torii_float_toggle() set_mode(mode == "float" and "tile" or "float") end
