require("modules.monitors")
require("modules.autostart")
require("modules.env")
require("modules.permissions")
require("modules.decorations")
require("modules.layout")
require("modules.animations")
require("modules.misc")
require("modules.input")
require("modules.binds")
require("modules.floatmode")
require("modules.windowbars")
require("modules.edgeresize")
require("modules.rules")

-- layout / gaps chosen in the launcher (Trigger menu), written by torii-hypr
pcall(dofile, os.getenv("HOME") .. "/.local/state/torii/hypr-user.lua")
-- per-app window rules chosen in the launcher (Setup > App rules), written by torii-rules
pcall(dofile, os.getenv("HOME") .. "/.local/state/torii/hypr-rules.lua")
-- keyboard shortcuts for launcher items (Ctrl+K on a row > Add binding), written by torii-binds
pcall(dofile, os.getenv("HOME") .. "/.local/state/torii/launcher-binds.lua")
