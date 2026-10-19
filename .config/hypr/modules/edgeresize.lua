-----------------------
---- EDGE RESIZE   ----
-----------------------
-- The title bar (hyprbars) covers the top edge of a floating window, so Hyprland offers no resize grab there. While the
-- cursor is on the strip just above a bar (or on the corner strips beside it), the "edge" submap is on: in it a left press
-- starts the resize drag (the corner nearest to the cursor moves). Out of the strip everything is as before. A reload runs
-- this file again; the timer is replaced then.
local function xy(t, k, i) return t[k] or t[i] or 0 end
local function bar_h()
    local ok, t = pcall(dofile, os.getenv("HOME") .. "/.local/state/torii/bars.lua")
    return ok and type(t) == "table" and tonumber(t.height) or 28
end

hl.define_submap("edge", function()
    hl.bind("mouse:272", hl.dsp.window.resize(), { mouse = true })
end)

local TOP, OUT, SIDE = 0, 10, 10      -- px of the bar that count (the bar itself keeps its press), px above it, width of the corner strips

local function in_zone()
    local c = hl.get_cursor_pos()
    if not c then return false end
    local cx, cy = xy(c, "x", 1), xy(c, "y", 2)
    local bh = bar_h()
    for _, w in ipairs(hl.get_windows()) do
        if w.floating and w.mapped and w.fullscreen == 0 and not w.hidden then
            local x, y, ww = xy(w.at, "x", 1), xy(w.at, "y", 2), xy(w.size, "x", 1)
            local top = y - bh
            if cx >= x - OUT and cx <= x + ww + OUT and cy >= top - OUT and cy <= top + TOP then return true end
            if cy >= top - OUT and cy <= y and (cx <= x + SIDE and cx >= x - OUT or cx >= x + ww - SIDE and cx <= x + ww + OUT) then return true end
        end
    end
    return false
end

local on = false
if torii_edge_poll then pcall(function() torii_edge_poll:stop() end) end
torii_edge_poll = hl.timer(function()
    local now = hl.get_current_submap and hl.get_current_submap() or ""
    if now ~= "" and now ~= "edge" then on = false; return end          -- the game keys, or another submap
    local z = in_zone()
    if z and not on then on = true; hl.dispatch(hl.dsp.submap("edge"))
    elseif not z and on then on = false; hl.dispatch(hl.dsp.submap("reset")) end
end, { timeout = 50, type = "repeat" })
