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

local mainMod = "ALT" -- Sets "Windows" key as main modifier

-- torii shell
local qsipc = "qs -c torii ipc call "
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-shell reload"))
hl.bind(mainMod .. " + SPACE",          hl.dsp.exec_cmd(qsipc .. "launcher toggle"))
hl.bind(mainMod .. " + N",              hl.dsp.exec_cmd(qsipc .. "control toggle"))
hl.bind(mainMod .. " + CTRL + SPACE",   hl.dsp.exec_cmd(qsipc .. "switcher toggle"))

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
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
--hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + R", hl.dsp.layout("togglesplit"))    -- dwindle only


-- Resize active window: mainMod + CTRL + arrow
local STEP = 100
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

-- Move active window: mainMod + SHIFT + arrow
local move = { left = "l", right = "r", up = "u", down = "d" }
for key, dir in pairs(move) do
    hl.bind(mainMod .. " + SHIFT + " .. key,
        hl.dsp.window.move({ direction = dir }))
end


-- MacOS like binds --
for _, key in ipairs({ "C", "V", "X", "Z", "A" }) do
    hl.bind(mainMod .. " + " .. key, function()
        local w = hl.get_active_window()
        local mods = "CTRL"
        if w and w.class == "kitty" then
            -- terminals: Ctrl+C would kill the running program, so only copy/paste,
            -- using the terminal's own Ctrl+Shift variants
            if key ~= "C" and key ~= "V" then return end
            mods = "CTRL SHIFT"
        end
        hl.dispatch(hl.dsp.send_shortcut({ mods = mods, key = key }))
    end)
end


-- Move focus with mainMod + arrow keys
-- mac style: in a terminal mainMod + left/right jump to the start/end of the line (Home/End), elsewhere they move focus
local function arrow(dir, key)
    return function()
        local w = hl.get_active_window()
        if w and w.class == "kitty" then
            hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = key }))
        else
            hl.dispatch(hl.dsp.focus({ direction = dir }))
        end
    end
end
hl.bind(mainMod .. " + left",  arrow("left", "Home"))
hl.bind(mainMod .. " + right", arrow("right", "End"))
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
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture screen"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture zone"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture record"))


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


--- FLOAT MODE TOGGLE ---
-- Two modes: "tile" (Hyprland default) and "float" (every window floats)
local float_mode = false
local FLOAT_X, FLOAT_Y = 1000, 650

-- New windows: float them if float mode is on
hl.on("window.open", function(w)
    if float_mode then
        hl.dispatch(hl.dsp.window.float({ action = "set", window = w }))
        hl.dispatch(hl.dsp.window.resize({ x = FLOAT_X, y = FLOAT_Y, window = w }))
        --hl.dispatch(hl.dsp.window.center({ window = w }))
    end
end)

-- Toggle the mode and convert the windows that are already open
--hl.bind(mainMod .. " + SHIFT + F", function()
--    float_mode = not float_mode
--    local action = float_mode and "set" or "unset"
--    for _, w in ipairs(hl.get_windows()) do
--       hl.dispatch(hl.dsp.window.float({ action = action, window = w }))
--       hl.dispatch(hl.dsp.window.resize({ x = FLOAT_X, y = FLOAT_Y, window = w }))
--    end
--    --hl.notification.create({ text = float_mode and "Float mode" or "Tile mode" })
--end)


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
