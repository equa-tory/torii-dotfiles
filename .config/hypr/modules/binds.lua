---------------------
---- MY PROGRAMS ----
---------------------
 
-- chosen in the launcher (Setup > Defaults); torii-default writes this file, the values below are the fallbacks
local function torii_defaults()
    local t = {}
    local f = io.open((os.getenv("HOME") or "") .. "/.local/state/torii/defaults.env")
    if f then
        for line in f:lines() do
            local k, v = line:match("^([%w_]+)=(.*)$")
            if k then t[k] = v end
        end
        f:close()
    end
    return t
end
local defaults = torii_defaults()

terminal = defaults.TORII_TERMINAL or "kitty"
fileManager = defaults.TORII_FILES or "dolphin"
menu = "hyprlauncher"
browser = defaults.TORII_BROWSER or "helium-browser"


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "ALT" -- main modifier (Alt everywhere; the Super key is left free)

-- Every bind made through bind() is remembered by its keys, so the game keys (below) can reuse any of them: which combinations
-- stay active in fullscreen games is listed in game-keys.lua, next to hyprland.lua.
torii_binds = {}
local function norm(keys)
    local parts = {}
    for p in tostring(keys):gsub("%s", ""):upper():gmatch("[^+]+") do parts[#parts + 1] = p end
    local key = table.remove(parts)
    table.sort(parts)
    return table.concat(parts, "+") .. (#parts > 0 and "+" or "") .. (key or "")
end
local function bind(keys, dispatcher, opts)
    torii_binds[norm(keys)] = { dispatcher = dispatcher, opts = opts }
    if opts then hl.bind(keys, dispatcher, opts) else hl.bind(keys, dispatcher) end
end

-- true while a torii panel (launcher, control panel, Alt+Tab, ...) has the keyboard
local function torii_panel_open()
    for _, l in ipairs(hl.get_layers({ namespace = "torii-notch" })) do
        if l.mapped and l.interactivity == 1 then return true end
    end
    return false
end
-- torii shell
local qsipc = "qs -c torii ipc call "
-- Reload the torii shell (after editing its config)
bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-shell reload"))
-- Open the launcher: apps, menus, search, calculator
bind(mainMod .. " + SPACE",          hl.dsp.exec_cmd(qsipc .. "launcher toggle"))
-- Open the control panel: sound, network, bluetooth, notifications
bind(mainMod .. " + N",              hl.dsp.exec_cmd(qsipc .. "control toggle"))
-- keys: SUPER + V | Clipboard history in the notch (type to filter, Enter pastes, Delete forgets one)
bind("SUPER + V", hl.dsp.exec_cmd(qsipc .. "clipboard toggle"))

-- Open the wallpaper / theme switcher
bind(mainMod .. " + CTRL + SPACE",   hl.dsp.exec_cmd(qsipc .. "switcher toggle"))
-- window switcher: Alt+Tab opens it on the previous window, more Tabs move on, letting go of Alt focuses
-- A quick tap (Alt released at once) switches without the menu ever showing; the menu opens when Alt is held on.
-- Hyprland sees the Alt release (the menu may not be open yet), so it tells the shell to commit.
-- Every Alt hold gets an id; the shell gets it with each call, because the separate `qs ipc` processes can arrive out
-- of order (a release before its own Tab) and a late release must not be taken for the next hold.
local tabbing, gesture, gestures = false, "", 0
local function tab(cmd)
    if not tabbing then
        gestures = gestures + 1
        gesture = os.time() .. "-" .. gestures
    end
    tabbing = true
    hl.exec_cmd(qsipc .. "windows " .. cmd .. " " .. gesture)
end
-- Alt+Tab: switch to the previous window; keep Alt held and press Tab again to walk the list
bind(mainMod .. " + TAB", function() tab("next") end)
-- Alt+Shift+Tab: walk the window list backwards
bind(mainMod .. " + SHIFT + TAB", function() tab("prev") end)
-- The Alt release is read from the raw key events: a release bind does not fire when Tab was pressed in between.
if torii_tab_sub then pcall(function() torii_tab_sub:remove() end) end     -- a reload runs this file again
torii_tab_sub = hl.on("input.keyboard.key", function(code, _, state)
    if state == 0 and (code == 64 or code == 108) and tabbing then      -- Alt_L / Alt_R (evdev code + 8)
        tabbing = false
        hl.exec_cmd(qsipc .. "windows commit " .. gesture)
    end
end)

-- Toggle fullscreen
bind(mainMod .. "+ SHIFT + F", function()
    hl.dispatch(hl.dsp.window.fullscreen({
        mode = "fullscreen", -- or fullscreen
        action = "toggle"
    }))
end)
-- Toggle maximize (keeps the bar visible)
bind(mainMod .. " + F", function()
    hl.dispatch(hl.dsp.window.fullscreen({
        mode = "maximized", -- or fullscreen
        action = "toggle"
    }))
end)

-- Open a terminal
bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
-- Open the browser
bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(browser))
-- Minimise the window (it stays in the Alt+Tab list)
bind(mainMod .. " + H", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-win min"))
-- Close the window (the selected one while Alt+Tab is open)
bind(mainMod .. " + Q", function()
    if torii_panel_open() then
        hl.exec_cmd("sh -c 'r=$(qs -c torii ipc call windows close); [ \"$r\" = ok ] || hyprctl dispatch \"hl.dsp.window.close()\"'")
    else
        hl.dispatch(hl.dsp.window.close())
    end
end)
-- Log out of the session
bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
-- Open the file manager
bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
-- Toggle floating for this window
bind(mainMod .. " + G", hl.dsp.window.float({ action = "toggle" }))
-- Pseudo-tile: the window keeps its own size inside its tile
bind(mainMod .. " + P", hl.dsp.window.pseudo())
-- Flip the split direction of the tiles (dwindle layout)
bind(mainMod .. " + R", hl.dsp.layout("togglesplit"))


-- keys: ALT + CTRL + ← ↑ ↓ → | Resize the window by 50 px (hold to keep going)
local STEP = 50
local resize = {
    left  = { x = -STEP, y = 0 },
    right = { x =  STEP, y = 0 },
    up    = { x = 0, y = -STEP },
    down  = { x = 0, y =  STEP },
}
for key, d in pairs(resize) do
    bind(mainMod .. " + CTRL + " .. key,
        hl.dsp.window.resize({ x = d.x, y = d.y, relative = true }),
        { repeating = true })   -- hold the keys to keep resizing
end

-- Make the window big (70 % of the screen, see Setup > Windows)
bind(mainMod .. " + CTRL + SHIFT + up",   function() if torii_window_big then torii_window_big() end end)
-- Centre the window at its normal size
bind(mainMod .. " + CTRL + SHIFT + down", function() if torii_window_center then torii_window_center() end end)

-- keys: ALT + SHIFT + ← ↑ ↓ → | Tiled window: move it in the layout (past a monitor edge to the next monitor). Floating window in tiling mode: nudge it a bit, at the screen edge left / right carry it to the next monitor. In float mode (Alt+Shift+N) left / right snap to a half and, pressed again, hop to the next monitor
local move = { left = "l", right = "r", up = "u", down = "d" }
for key, dir in pairs(move) do
    bind(mainMod .. " + SHIFT + " .. key, function()
        if torii_float_snap and torii_float_snap(key) then return end
        hl.dispatch(hl.dsp.window.move({ direction = dir }))
    end)
end


-- keys: ALT + C / V / X / Z / A | Copy, paste, cut, undo, select all in every app (Mac style; in a terminal only copy / paste)
-- keys: SUPER + ← / → | Jump to the start / end of the line in every app (+ SHIFT selects)
-- (implementation) Alt + C/V/X/Z/A act like the Mac's copy/paste/cut/undo/select all and Super + Left/Right
-- jump to the start/end of the line, in every app. While a torii panel (launcher, control panel) has the keyboard these
-- would hit the window underneath, so they are forwarded to the panel's text field instead.
local qs_text = "qs -c torii ipc call text edit "

for _, key in ipairs({ "C", "V", "X", "Z", "A" }) do
    local action = ({ C = "copy", V = "paste", X = "cut", Z = "undo", A = "selectall" })[key]
    bind(mainMod .. " + " .. key, function()
        if torii_panel_open() then hl.exec_cmd(qs_text .. action); return end
        local w = hl.get_active_window()
        local mods = "CTRL"
        if w and w.class == "kitty" then
            -- terminals: Ctrl+C would kill the running program, so only copy/paste,
            -- using the terminal's own Ctrl+Shift variants
            if key ~= "C" and key ~= "V" then return end
            mods = "CTRL SHIFT"
        end
        -- press and release in one go: send_shortcut waits for the physical key to come up before it releases, and
        -- when Alt is let go before the letter the app is left holding it and repeats it ("vvvv")
        hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
        hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end)
end

for _, e in ipairs({
    { "left",  "Home", "home" },  { "right", "End", "end" },
}) do
    local dir, key, action = e[1], e[2], e[3]
    bind("SUPER + " .. dir, function()
        if torii_panel_open() then hl.exec_cmd(qs_text .. action); return end
        hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = key }))
    end)
    bind("SUPER + SHIFT + " .. dir, function()      -- select to the start/end of the line
        if torii_panel_open() then hl.exec_cmd(qs_text .. "select" .. action); return end
        hl.dispatch(hl.dsp.send_shortcut({ mods = "SHIFT", key = key }))
    end)
end


-- keys: ALT + ← / → | Focus the window on the left / right, across monitors (moves the selection while Alt+Tab is open)
for _, d in ipairs({ "left", "right" }) do
    bind(mainMod .. " + " .. d, function()
        if torii_panel_open() then
            hl.exec_cmd("sh -c 'r=$(qs -c torii ipc call windows " .. d .. "); [ \"$r\" = ok ] || hyprctl dispatch \"hl.dsp.focus({ direction = \\\"" .. d .. "\\\" })\"'")
        else
            hl.dispatch(hl.dsp.focus({ direction = d }))
        end
    end)
end
-- Focus the window above
bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
-- Focus the window below
bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))


-- keys: ALT + 1 … 0 | Go to workspace 1 … 10
-- keys: ALT + SHIFT + 1 … 0 | Move the window to workspace 1 … 10
--for i = 1, 10 do
--    local key = i % 10 -- 10 maps to key 0
--    bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
--    -- SHIFT+3/4/5 are the screenshot binds below (like macOS), so moving a window to workspace 3, 4, 5 is CTRL+ instead
--    local moveMods = (i >= 3 and i <= 5) and " + CTRL + " or " + SHIFT + "
--    bind(mainMod .. moveMods .. key,          hl.dsp.window.move({ workspace = i }))
--end
for i = 1, 10 do
    local key = i % 10
    bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
    -- keys: ALT + SUPER + SHIFT + 1 … 0 | Send the window to workspace 1 … 10 without going there
    bind(mainMod .. " + SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- keys: ALT + W, letter or digit | Go to the workspace of that letter (a-z) or number (1-9, 0 = 10); the letters are chosen per app in Setup > App rules > Workspace
-- keys: ALT + SHIFT + W, letter | Move the window to the workspace of that letter
-- (implementation) Alt+W waits for one letter in a short-lived submap (Esc or any other key cancels; there is no timeout, so the mouse can be used in between). Letter workspaces are
-- named ones ("name:b"); they do not touch the numbered workspaces.
local function letter_submap(name, label, action)
    hl.define_submap(name, function()
        for code = 97, 122 do
            local l = string.char(code)
            hl.bind(l, function()
                action(l)
                hl.dispatch(hl.dsp.submap("reset"))
            end)
        end
        for d = 0, 9 do
            hl.bind(tostring(d), function()
                action(d == 0 and 10 or d)
                hl.dispatch(hl.dsp.submap("reset"))
            end)
        end
        hl.bind("Escape", hl.dsp.submap("reset"))
        pcall(function() hl.bind("catchall", hl.dsp.submap("reset")) end)
    end)
end
-- A letter workspace comes to the monitor you are on instead of sending you to the monitor it was last shown on
-- (otherwise an emptied letter workspace stays open on the other screen).
local function focused_monitor()
    for _, m in ipairs(hl.get_monitors()) do if m.focused then return m.name end end
end
letter_submap("wsgo", "go", function(l)
    local mon = type(l) == "string" and focused_monitor()
    if mon then pcall(function() hl.dispatch(hl.dsp.workspace.move({ workspace = "name:" .. l, monitor = mon })) end) end
    hl.dispatch(hl.dsp.focus({ workspace = type(l) == "number" and l or "name:" .. l }))
end)
letter_submap("wsmove", "move", function(l) hl.dispatch(hl.dsp.window.move({ workspace = type(l) == "number" and l or "name:" .. l })) end)
letter_submap("wssend", "send", function(l) hl.dispatch(hl.dsp.window.move({ workspace = type(l) == "number" and l or "name:" .. l, follow = false })) end)
local function wait_letter(name)
    return function() hl.dispatch(hl.dsp.submap(name)) end
end
bind(mainMod .. " + W", wait_letter("wsgo"))
bind(mainMod .. " + SHIFT + W", wait_letter("wsmove"))
-- keys: ALT + SUPER + SHIFT + W, letter or digit | Send the window to that workspace without going there
bind(mainMod .. " + SUPER + SHIFT + W", wait_letter("wssend"))


-- Screenshots and recording (torii-capture): whole screen, a zone, and start/stop screen recording
-- Screenshot of the whole screen
bind("SUPER + SHIFT + Q", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture screen"))
-- Screenshot of a zone you select
bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture zone"))
-- Start / stop screen recording
bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture record"))
-- Copy the text from a zone of the screen (OCR)
bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture text"))


-- Show / hide the special workspace (scratchpad)
bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
-- Send the window to the special workspace
bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))


-- Scroll through existing workspaces with mainMod + scroll
-- Next workspace (scroll down)
bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
-- Previous workspace (scroll up)
bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))


-- Move/resize windows with mainMod + LMB/RMB and dragging
-- Hold and drag with the left mouse button to move a window
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
-- Hold and drag with the right mouse button to resize a window
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-- Laptop multimedia keys for volume and LCD brightness
-- Volume up
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { submap_universal = true, locked = true, repeating = true })
-- Volume down
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { submap_universal = true, locked = true, repeating = true })
-- keys: ALT + SHIFT + + / - | Volume up / down (keyboard without media keys); works in fullscreen games too
for _, k in ipairs({ "equal", "plus", "KP_Add" }) do
    bind(mainMod .. " + SHIFT + " .. k, hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { submap_universal = true, repeating = true })
end
for _, k in ipairs({ "minus", "KP_Subtract" }) do
    bind(mainMod .. " + SHIFT + " .. k, hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { submap_universal = true, repeating = true })
end
-- Mute / unmute the sound
bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { submap_universal = true, locked = true, repeating = true })
-- Mute / unmute the microphone
bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { submap_universal = true, locked = true, repeating = true })
-- Brightness up
bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { submap_universal = true, locked = true, repeating = true })
-- Brightness down
bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { submap_universal = true, locked = true, repeating = true })


-- Media keys (need playerctl)
-- Previous track
bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { submap_universal = true, locked = true })
-- Previous track
bind(mainMod .. " + comma",  hl.dsp.exec_cmd("playerctl previous"),       { locked = true })
-- Play / pause
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { submap_universal = true, locked = true })
-- Play / pause
bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { submap_universal = true, locked = true })
-- Play / pause
bind(mainMod .. " + period",  hl.dsp.exec_cmd("playerctl play-pause"),       { locked = true })
-- Next track
bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { submap_universal = true, locked = true })
-- Next track
bind(mainMod .. " + slash",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })


-- Switch between dark and light mode (torii-theme restyles everything)
bind(mainMod .. " + SHIFT + D",hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-theme mode toggle"))

-- Keyboard layout: mainMod+SHIFT pressed and released on their own.
-- Release binds don't fire if another key was pressed in between, so
-- mainMod+SHIFT+<key> binds (e.g. RETURN) are not affected.
-- The released key has to be listed in the modifiers too, once per release order.
local switchLayout = hl.dsp.exec_cmd("hyprctl switchxkblayout all next")
-- Switch the keyboard layout: press and release Alt + Shift on their own
bind(mainMod .. " + SHIFT + Shift_L", switchLayout, { release = true })
-- (same, when Shift is let go first)
bind(mainMod .. " + SHIFT + " .. mainMod:sub(1, 1) .. mainMod:sub(2):lower() .. "_L", switchLayout, { release = true })

-- Games: Alt is the main modifier here, so Alt+1..0 and friends would never reach a game that uses them. While a Steam game
-- (Proton windows are "steam_app_<id>") is fullscreen and has the focus, the normal binds are off and only these few stay
-- (Alt+Space launcher, Alt+N control centre, Alt+Tab, Alt+Enter terminal, Alt+Shift+Enter browser, Alt+W / Alt+Shift+W workspace letter; the media keys are "submap_universal", so they work as always). Out of fullscreen (Alt+Shift+F) every bind works again.
-- While a panel (launcher, control centre, Alt+Tab) is open every bind works too. Alt+Shift+G switches the game keys off by hand (until the focus or fullscreen changes).
hl.define_submap("game", function()
    local ok, allowed = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/game-keys.lua")
    for _, keys in ipairs(ok and type(allowed) == "table" and allowed or {}) do
        local b = torii_binds[norm(keys)]
        if b then
            if b.opts then hl.bind(keys, b.dispatcher, b.opts) else hl.bind(keys, b.dispatcher) end
        end
    end
    hl.bind(mainMod .. " + SHIFT + G", hl.dsp.submap("reset"))
end)
local function game_keys()
    local w = hl.get_active_window()
    local game = w ~= nil and (w.class or ""):match("^steam_app_%d+$") ~= nil and w.fullscreen ~= 0 and not torii_panel_open()
    -- leaving for another (maybe empty) workspace can keep the game as the "active window" for a while: it only counts while it is on screen
    if game then
        local ws, cur = w.workspace, hl.get_active_workspace and hl.get_active_workspace()
        if ws and cur and ws.id ~= cur.id then game = false end
    end
    local now = hl.get_current_submap and hl.get_current_submap() or ""
    if now == "wsgo" or now == "wsmove" or now == "wssend" then return end -- waiting for the workspace letter: do not cancel it
    if game and now ~= "game" then hl.dispatch(hl.dsp.submap("game"))
    elseif not game and now == "game" then hl.dispatch(hl.dsp.submap("reset")) end
end
-- an open panel (launcher...) gives every bind back; its closing is not an event, so the state is looked at a few times a second
if torii_game_poll then pcall(function() torii_game_poll:stop() end) end
torii_game_poll = hl.timer(function()
    local now = hl.get_current_submap and hl.get_current_submap() or ""
    if now == "game" or hl.get_active_window() ~= nil then game_keys() end
end, { timeout = 300, type = "repeat" })
for _, ev in ipairs({ "window.active", "window.fullscreen", "workspace.active" }) do
    local v = "torii_game_sub_" .. ev:gsub("%.", "_")
    if _G[v] then pcall(function() _G[v]:remove() end) end     -- a reload runs this file again
    pcall(function() _G[v] = hl.on(ev, function() hl.timer(game_keys, { timeout = 50, type = "oneshot" }) end) end)
end

-- an empty submap: while the launcher waits for a key combination (Ctrl+K > Add binding) Hyprland's own binds let every key through.
-- (the dummy bind is only there because a submap without any bind is not registered)
hl.define_submap("capture", function()
    hl.bind("XF86Launch9", hl.dsp.submap("reset"))
end)
