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
-- Reload the torii shell (after editing its config)
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-shell reload"))
-- Open the launcher: apps, menus, search, calculator
hl.bind(mainMod .. " + SPACE",          hl.dsp.exec_cmd(qsipc .. "launcher toggle"))
-- Open the control panel: sound, network, bluetooth, notifications
hl.bind(mainMod .. " + N",              hl.dsp.exec_cmd(qsipc .. "control toggle"))
-- Open the wallpaper / theme switcher
hl.bind(mainMod .. " + CTRL + SPACE",   hl.dsp.exec_cmd(qsipc .. "switcher toggle"))
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
hl.bind(mainMod .. " + TAB", function() tab("next") end)
-- Alt+Shift+Tab: walk the window list backwards
hl.bind(mainMod .. " + SHIFT + TAB", function() tab("prev") end)
-- The Alt release is read from the raw key events: a release bind does not fire when Tab was pressed in between.
if torii_tab_sub then pcall(function() torii_tab_sub:remove() end) end     -- a reload runs this file again
torii_tab_sub = hl.on("input.keyboard.key", function(code, _, state)
    if state == 0 and (code == 64 or code == 108) and tabbing then      -- Alt_L / Alt_R (evdev code + 8)
        tabbing = false
        hl.exec_cmd(qsipc .. "windows commit " .. gesture)
    end
end)

-- Toggle fullscreen
hl.bind(mainMod .. "+ SHIFT + F", function()
    hl.dispatch(hl.dsp.window.fullscreen({
        mode = "fullscreen", -- or fullscreen
        action = "toggle"
    }))
end)
-- Toggle maximize (keeps the bar visible)
hl.bind(mainMod .. " + F", function()
    hl.dispatch(hl.dsp.window.fullscreen({
        mode = "maximized", -- or fullscreen
        action = "toggle"
    }))
end)

-- Open a terminal
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
-- Open the browser
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(browser))
-- Minimise the window (it stays in the Alt+Tab list)
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-win min"))
-- Close the window (the selected one while Alt+Tab is open)
hl.bind(mainMod .. " + Q", function()
    if torii_panel_open() then
        hl.exec_cmd("sh -c 'r=$(qs -c torii ipc call windows close); [ \"$r\" = ok ] || hyprctl dispatch \"hl.dsp.window.close()\"'")
    else
        hl.dispatch(hl.dsp.window.close())
    end
end)
-- Log out of the session
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
-- Open the file manager
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
-- Toggle floating for this window
hl.bind(mainMod .. " + G", hl.dsp.window.float({ action = "toggle" }))
-- Pseudo-tile: the window keeps its own size inside its tile
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
-- Flip the split direction of the tiles (dwindle layout)
hl.bind(mainMod .. " + R", hl.dsp.layout("togglesplit"))


-- keys: ALT + CTRL + ← ↑ ↓ → | Resize the window by 50 px (hold to keep going)
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

-- Make the window big (70 % of the screen, see Setup > Windows)
hl.bind(mainMod .. " + CTRL + SHIFT + up",   function() if torii_window_big then torii_window_big() end end)
-- Centre the window at its normal size
hl.bind(mainMod .. " + CTRL + SHIFT + down", function() if torii_window_center then torii_window_center() end end)

-- keys: ALT + SHIFT + ← ↑ ↓ → | Move the window; past a monitor edge it goes to the next monitor; in float mode left / right snap to a half and, pressed again, hop to the next monitor
local move = { left = "l", right = "r", up = "u", down = "d" }
for key, dir in pairs(move) do
    hl.bind(mainMod .. " + SHIFT + " .. key, function()
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


-- keys: ALT + ← / → | Focus the window on the left / right, across monitors (moves the selection while Alt+Tab is open)
for _, d in ipairs({ "left", "right" }) do
    hl.bind(mainMod .. " + " .. d, function()
        if torii_panel_open() then
            hl.exec_cmd("sh -c 'r=$(qs -c torii ipc call windows " .. d .. "); [ \"$r\" = ok ] || hyprctl dispatch \"hl.dsp.focus({ direction = \\\"" .. d .. "\\\" })\"'")
        else
            hl.dispatch(hl.dsp.focus({ direction = d }))
        end
    end)
end
-- Focus the window above
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
-- Focus the window below
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))


-- keys: ALT + 1 … 0 | Go to workspace 1 … 10
-- keys: ALT + SHIFT + 1 … 0 | Move the window to workspace 1 … 10
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
-- Screenshot of the whole screen
hl.bind("SUPER + SHIFT + Q", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture screen"))
-- Screenshot of a zone you select
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture zone"))
-- Start / stop screen recording
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture record"))
-- Copy the text from a zone of the screen (OCR)
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-capture text"))


-- Show / hide the special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
-- Send the window to the special workspace
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))


-- Scroll through existing workspaces with mainMod + scroll
-- Next workspace (scroll down)
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
-- Previous workspace (scroll up)
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))


-- Move/resize windows with mainMod + LMB/RMB and dragging
-- Hold and drag with the left mouse button to move a window
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
-- Hold and drag with the right mouse button to resize a window
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-- Laptop multimedia keys for volume and LCD brightness
-- Volume up
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
-- Volume down
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
-- Mute / unmute the sound
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
-- Mute / unmute the microphone
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
-- Brightness up
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
-- Brightness down
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })


-- Media keys (need playerctl)
-- Previous track
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
-- Previous track
hl.bind(mainMod .. " + comma",  hl.dsp.exec_cmd("playerctl previous"),       { locked = true })
-- Play / pause
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
-- Play / pause
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
-- Play / pause
hl.bind(mainMod .. " + period",  hl.dsp.exec_cmd("playerctl play-pause"),       { locked = true })
-- Next track
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
-- Next track
hl.bind(mainMod .. " + slash",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })


-- Switch between dark and light mode (torii-theme restyles everything)
hl.bind(mainMod .. " + SHIFT + D",hl.dsp.exec_cmd("$HOME/.config/torii/bin/torii-theme mode toggle"))

-- Keyboard layout: mainMod+SHIFT pressed and released on their own.
-- Release binds don't fire if another key was pressed in between, so
-- mainMod+SHIFT+<key> binds (e.g. RETURN) are not affected.
-- The released key has to be listed in the modifiers too, once per release order.
local switchLayout = hl.dsp.exec_cmd("hyprctl switchxkblayout all next")
-- Switch the keyboard layout: press and release Alt + Shift on their own
hl.bind(mainMod .. " + SHIFT + Shift_L", switchLayout, { release = true })
-- (same, when Shift is let go first)
hl.bind(mainMod .. " + SHIFT + " .. mainMod:sub(1, 1) .. mainMod:sub(2):lower() .. "_L", switchLayout, { release = true })
