-----------------
---- MONITORS ----
------------------

hl.monitor({ output = "DP-2", mode = "1920x1080@240", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "1920x0", scale = 1 })

-- Workspace 1 lives on the main monitor (DP-2) and 2 on the second one, so DP-2 never starts on "workspace 2"
-- (Hyprland gives workspace 1 to whichever monitor is ready first, which was HDMI-A-1). The rest follow the focused monitor.
hl.workspace_rule({ workspace = "1", monitor = "DP-2",     default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1", default = true, persistent = true })
