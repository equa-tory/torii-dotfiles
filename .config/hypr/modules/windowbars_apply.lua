-----------------------
---- WINDOW BARS   ----
-----------------------
-- Applied by windowbars.lua once the plugin is loaded (hl.plugin.load does not load it from the config).
-- Title bars (close / minimise / maximise, drag to move, double-click to maximise) on floating windows, drawn by the
-- hyprbars plugin. Tiled windows have none. Height and the side of the buttons are chosen in Setup > Windows
-- (torii-hypr bars), kept in ~/.local/state/torii/bars.lua.

local STATE = os.getenv("HOME") .. "/.local/state/torii/"
local win = os.getenv("HOME") .. "/.config/torii/bin/torii-win"

local bars = { height = 28, side = "right" }
do
    local ok, saved = pcall(dofile, STATE .. "bars.lua")
    if ok and type(saved) == "table" then
        bars.height = tonumber(saved.height) or bars.height
        bars.side = saved.side == "left" and "left" or "right"
    end
end

if hl.plugin.hyprbars then
    hl.config({
        plugin = {
            hyprbars = {
                bar_height                 = bars.height,
                bar_padding                = 10,
                bar_button_padding         = 8,
                bar_precedence_over_border = true,
                bar_part_of_window         = true,
                bar_buttons_alignment      = bars.side,
                bar_text_align             = "center",
                bar_text_size              = 11,
                icon_on_hover              = true,
                on_double_click            = win .. " dblclick",
            },
        },
    })
    pcall(dofile, STATE .. "theme/hyprbars.lua")      -- colours from the wallpaper theme

    local function button(color, icon, action)
        hl.plugin.hyprbars.add_button({
            bg_color = color, fg_color = "rgb(1a1a1a)", size = math.max(12, math.floor(bars.height * 0.5)), icon = icon,
            action = win .. " " .. action,
        })
    end
    -- the button next to the window edge comes first: close, then minimise + maximise (left, like macOS) or the reverse
    button("rgb(ff5f56)", "×", "close")
    if bars.side == "left" then
        button("rgb(ffbd2e)", "−", "min")
        button("rgb(27c93f)", "+", "max")
    else
        button("rgb(27c93f)", "+", "max")
        button("rgb(ffbd2e)", "−", "min")
    end

    -- no bar on tiled windows
    hl.window_rule({ name = "torii-nobar-tiled", match = { float = false }, ["hyprbars:no_bar"] = true })
end
