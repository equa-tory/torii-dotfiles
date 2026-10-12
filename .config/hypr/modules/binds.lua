---------------------
---- MY PROGRAMS ----
---------------------
 
terminal = "kitty"
fileManager = "dolphin"
menu = "hyprlauncher"
browser = "helium-browser"


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "ALT" -- Sets "Windows" key as main modifier

hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(
    "pkill waybar; waybar & pkill hyprpaper; hyprpaper &"
))

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))
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
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))


-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end


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
hl.bind(mainMod .. " + SHIFT + F", function()
    float_mode = not float_mode
    local action = float_mode and "set" or "unset"
    for _, w in ipairs(hl.get_windows()) do
       hl.dispatch(hl.dsp.window.float({ action = action, window = w }))
       hl.dispatch(hl.dsp.window.resize({ x = FLOAT_X, y = FLOAT_Y, window = w }))
    end
    --hl.notification.create({ text = float_mode and "Float mode" or "Tile mode" })
end)
