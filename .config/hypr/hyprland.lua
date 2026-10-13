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
require("modules.rules")

-- layout / gaps chosen in the launcher (Trigger menu), written by torii-hypr
pcall(dofile, os.getenv("HOME") .. "/.local/state/torii/hypr-user.lua")
