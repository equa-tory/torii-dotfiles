-- Retire the old cursor-polled edge submap. It checked every floating window,
-- including covered windows, and could turn an ordinary click into a resize.
-- Keep cleanup here so reloading an existing session stops its old timer.
if torii_edge_poll then
    pcall(function() torii_edge_poll:stop() end)
    torii_edge_poll = nil
end
if hl.get_current_submap and hl.get_current_submap() == "edge" then
    hl.dispatch(hl.dsp.submap("reset"))
end
-- Native border resizing and Alt+right-drag are configured elsewhere.
