-- Enter / Right / o: a folder is entered, anything else goes to torii-open (the apps chosen in Setup > Defaults > Open files with).
-- (stock `open` and the opener rules are bypassed on purpose.)
local hovered_is_dir = ya.sync(function()
	local h = cx.active.current.hovered
	return h ~= nil and h.cha.is_dir
end)
local has_hovered = ya.sync(function() return cx.active.current.hovered ~= nil end)

return {
	entry = function()
		if not has_hovered() then return end
		if hovered_is_dir() then
			ya.emit("enter", {})
		else
			ya.emit("shell", { 'torii-open "$@"', block = true })
		end
	end,
}
