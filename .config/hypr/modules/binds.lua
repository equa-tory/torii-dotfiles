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

-- true while a torii panel (launcher, control panel, Alt+Tab, ...) has the keyboard
local function torii_panel_open()
    for _, l in ipairs(hl.get_layers({ namespace = "torii-notch" })) do
        if l.mapped and l.interactivity == 1 then return true end
    end
    return false
end
-- torii shell
local qsipc = "qs -c torii ipc call "
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-shell reload"))
hl.bind(mainMod .. " + SPACE",          hl.dsp.exec_cmd(qsipc .. "launcher toggle"))
hl.bind(mainMod .. " + N",              hl.dsp.exec_cmd(qsipc .. "control toggle"))
hl.bind(mainMod .. " + CTRL + SPACE",   hl.dsp.exec_cmd(qsipc .. "switcher toggle"))
-- window switcher: Alt+Tab opens it on the previous window, more Tabs move on, letting go of Alt focuses
-- A quick tap (Alt released at once) switches without the menu ever showing; the menu opens when Alt is held on.
-- Hyprland sees the Alt release (the menu may not be open yet), so it tells the shell to commit.
local tabbing = false
hl.bind(mainMod .. " + TAB", function()
    tabbing = true
    hl.exec_cmd(qsipc .. "windows next")
end)
hl.bind(mainMod .. " + SHIFT + TAB", function()
    tabbing = true
    hl.exec_cmd(qsipc .. "windows prev")
end)
hl.bind("Alt_L", function()
    if tabbing then
        tabbing = false
        hl.exec_cmd(qsipc .. "windows commit")
    end
end, { release = true, ignore_mods = true, non_consuming = true })

hl.bind(mainMod .. "+ SHIFT + F", function()
    hl.dispatch(hl.dsp.window.fullscreen({
        mode = "fullscreen", -- or fullscreen
        action = "toggle"
    }))
end)
hl.bind(mainMod .. " + F", function()
    hl.dispatch(hl.dsp.window.fullscreen({
        mode = "maximized", -- or fullscreen
        action = "toggle"
    }))
end)

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(browser))
-- Alt+Q closes the active window, or the selected one while Alt+Tab is open
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-win min"))   -- minimise (still listed in Alt+Tab)
hl.bind(mainMod .. " + Q", function()
    if torii_panel_open() then
        hl.exec_cmd("sh -c 'r=$(qs -c torii ipc call windows close); [ \"$r\" = ok ] || hyprctl dispatch \"hl.dsp.window.close()\"'")
    else
        hl.dispatch(hl.dsp.window.close())
    end
end)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + G", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + R", hl.dsp.layout("togglesplit"))    -- dwindle only


-- Resize active window: mainMod + CTRL + arrow
local STEP = 50
local resize = {
    left  = { x = -STEP, y = 0 },
    right = { x =  STEP, y = 0 },
    up    = { x = 0, y = -STEP },
    down  = { x = 0, y =  STEP },
}
for key, d in pairs(resize) do
    hl.bind(mainMod .. " + CTRL + " .. key,
        hl.dsp.window.resize({ x = d.x, y = d.y, relative = true }),
        { repeating = true })   -- hold the keys to keep resizing
end

-- Big / centred window (floatmode.lua): Ctrl+Alt+Shift+Up takes 70 % of the screen (Setup > Windows), +Down centres it
hl.bind(mainMod .. " + CTRL + SHIFT + up",   function() if torii_window_big then torii_window_big() end end)
hl.bind(mainMod .. " + CTRL + SHIFT + down", function() if torii_window_center then torii_window_center() end end)

-- Move active window: mainMod + SHIFT + arrow (past the edge of a monitor it goes to the next monitor)
local move = { left = "l", right = "r", up = "u", down = "d" }
-- In float mode the same keys snap the window to the left / right half (up: fill the screen, down: back to where it was).
for key, dir in pairs(move) do
    hl.bind(mainMod .. " + SHIFT + " .. key, function()
        if torii_float_snap and torii_float_snap(key) then return end
        hl.dispatch(hl.dsp.window.move({ direction = dir }))
    end)
end


-- Text editing keys. Alt (mainMod) + C/V/X/Z/A act like the Mac's copy/paste/cut/undo/select all and Super + Left/Right
-- jump to the start/end of the line, in every app. While a torii panel (launcher, control panel) has the keyboard these
-- would hit the window underneath, so they are forwarded to the panel's text field instead.
local qs_text = "qs -c torii ipc call text edit "

for _, key in ipairs({ "C", "V", "X", "Z", "A" }) do
    local action = ({ C = "copy", V = "paste", X = "cut", Z = "undo", A = "selectall" })[key]
    hl.bind(mainMod .. " + " .. key, function()
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
    hl.bind("SUPER + " .. dir, function()
        if torii_panel_open() then hl.exec_cmd(qs_text .. action); return end
        hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = key }))
    end)
    hl.bind("SUPER + SHIFT + " .. dir, function()      -- select to the start/end of the line
        if torii_panel_open() then hl.exec_cmd(qs_text .. "select" .. action); return end
        hl.dispatch(hl.dsp.send_shortcut({ mods = "SHIFT", key = key }))
    end)
end


-- Move focus with mainMod + arrow keys (across monitors too)
-- (in Alt+Tab, left / right move the selection instead)
for _, d in ipairs({ "left", "right" }) do
    hl.bind(mainMod .. " + " .. d, function()
        if torii_panel_open() then
            hl.exec_cmd("sh -c 'r=$(qs -c torii ipc call windows " .. d .. "); [ \"$r\" = ok ] || hyprctl dispatch \"hl.dsp.focus({ direction = \\\"" .. d .. "\\\" })\"'")
        else
            hl.dispatch(hl.dsp.focus({ direction = d }))
        end
    end)
end
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))


-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
--for i = 1, 10 do
--    local key = i % 10 -- 10 maps to key 0
--    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
--    -- SHIFT+3/4/5 are the screenshot binds below (like macOS), so moving a window to workspace 3, 4, 5 is CTRL+ instead
--    local moveMods = (i >= 3 and i <= 5) and " + CTRL + " or " + SHIFT + "
--    hl.bind(mainMod .. moveMods .. key,          hl.dsp.window.move({ workspace = i }))
--end
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Screenshots and recording (torii-capture): whole screen, a zone, and start/stop screen recording
hl.bind("SUPER + SHIFT + Q", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture screen"))
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture zone"))
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture record"))
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture text"))


-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))


-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))


-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })


-- Requires playerctl
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind(mainMod .. " + comma",  hl.dsp.exec_cmd("playerctl previous"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind(mainMod .. " + period",  hl.dsp.exec_cmd("playerctl play-pause"),       { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind(mainMod .. " + slash",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })


-- Dark / light mode (torii-theme restyles everything; dark is the default)
-- Keyboard layout (a normal bind, so it doesn't fire on mainMod+SHIFT+<other key>)
hl.bind(mainMod .. " + SHIFT + D",hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-theme mode toggle"))

-- Keyboard layout: mainMod+SHIFT pressed and released on their own.
-- Release binds don't fire if another key was pressed in between, so
-- mainMod+SHIFT+<key> binds (e.g. RETURN) are not affected.
-- The released key has to be listed in the modifiers too, once per release order.
local switchLayout = hl.dsp.exec_cmd("hyprctl switchxkblayout all next")
hl.bind(mainMod .. " + SHIFT + Shift_L", switchLayout, { release = true })
hl.bind(mainMod .. " + SHIFT + " .. mainMod:sub(1, 1) .. mainMod:sub(2):lower() .. "_L", switchLayout, { release = true })
