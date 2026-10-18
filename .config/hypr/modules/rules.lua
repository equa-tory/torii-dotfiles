--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Small terminal windows opened by the launcher (Install, Remove, Update, Learn notes)
hl.window_rule({
    name  = "torii-float",
    match = { class = "^torii-float$" },

    float  = true,
    center = true,
    size   = { 960, 620 },
})

-- Steam games (Proton windows are "steam_app_<id>"): open on the 240 Hz monitor, not wherever the focus was (the HDMI one
-- only offers 60 Hz, so a game that opened there could not pick 240). Fullscreen: see the window.open hook below.
-- immediate = no vsync wait, lowest latency.
hl.window_rule({
    name  = "torii-steam-games",
    match = { class = "^steam_app_[0-9]+$" },

    monitor   = "DP-2",
    immediate = true,
})

-- The game's own fullscreen mode breaks the mouse under XWayland (buttons do not click, and the game takes fullscreen back
-- whenever you leave it), so the game stays windowed (video.txt "setting.fullscreen" 0) and Hyprland makes it fullscreen once
-- when it opens. Alt+Shift+F then leaves and enters fullscreen as for any window.
if torii_steam_sub then pcall(function() torii_steam_sub:remove() end) end     -- a reload runs this file again
torii_steam_sub = hl.on("window.open", function(w)
    if not (w.class or ""):match("^steam_app_%d+$") then return end
    local addr = w.address
    hl.timer(function()
        os.execute(string.format("hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"set\", window = \"address:%s\" })' >/dev/null 2>&1 &", addr))
    end, { timeout = 1500, type = "oneshot" })
end)
