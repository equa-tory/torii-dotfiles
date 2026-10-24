-- Key combinations that keep working while a Steam game is fullscreen and focused (everything else goes to the game).
-- One entry per combination, written like the binds in modules/binds.lua (modifier order does not matter). Remove a line to hand
-- that combination to the game; add a line to keep one of the normal binds working. Only binds from modules/binds.lua can be listed.
-- Reload with `hyprctl reload`. (Alt+Shift+G, which turns the game keys off by hand, is always there.)
return {
    "ALT + SHIFT + F",         -- fullscreen on / off
    "ALT + TAB",               -- switch window
    "ALT + SHIFT + TAB",
    "ALT + SPACE",             -- launcher
    "ALT + N",                 -- control centre
    "ALT + RETURN",            -- terminal (Alt+Enter is "fullscreen" in many games)
    "ALT + SHIFT + RETURN",    -- browser
    "ALT + W",                 -- workspace letter / digit
    "ALT + SHIFT + W",
    "SUPER + SHIFT + Q",       -- screenshot: screen
    "SUPER + SHIFT + W",       -- screenshot: zone
    "SUPER + SHIFT + E",       -- screen recording
    "SUPER + SHIFT + R",       -- text from the screen
}
