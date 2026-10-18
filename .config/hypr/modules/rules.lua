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
-- only offers 60 Hz, so a game that opened there could not pick 240). Fullscreen is left to the game's own setting, so you can
-- still switch it in the options. immediate = no vsync wait, lowest latency.
hl.window_rule({
    name  = "torii-steam-games",
    match = { class = "^steam_app_[0-9]+$" },

    monitor   = "DP-2",
    immediate = true,
})
