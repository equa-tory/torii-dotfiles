-- Require an observed Alt press for mouse move/resize, rather than trusting
-- a stale compositor modifier mask after a focus change or keyboard grab.
local held = {}
if torii_mouse_alt_sub then pcall(function() torii_mouse_alt_sub:remove() end) end
torii_mouse_alt_sub = hl.on("input.keyboard.key", function(code, _, state)
    if code == 64 or code == 108 then -- XKB keycodes: left/right Alt
        held[code] = state ~= 0
    end
end)
function torii_guard_mouse(dispatcher)
    return function()
        if held[64] or held[108] then hl.dispatch(dispatcher) end
    end
end
