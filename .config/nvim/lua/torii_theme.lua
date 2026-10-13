-- Wallpaper-driven colours from torii-theme. Falls back to stock catppuccin mocha when the file is missing.
local M = {}

local path = vim.fn.expand("~/.local/state/torii/theme/nvim.lua")

local function load()
  local ok, t = pcall(dofile, path)
  if ok and type(t) == "table" then return t end
  return { flavour = "mocha", mode = "dark", colors = nil }
end

function M.apply()
  local t = load()
  local overrides = t.colors and { [t.flavour] = t.colors } or {}
  vim.o.background = t.mode
  require("catppuccin").setup({ flavour = t.flavour, color_overrides = overrides })
  vim.cmd.colorscheme("catppuccin-" .. t.flavour)
end

-- called by `torii-theme` in every running nvim
function M.reload()
  pcall(M.apply)
end

return M
