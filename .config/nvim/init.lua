vim.opt.colorcolumn = "100"
vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.termguicolors = true

require("nvim-highlight-colors").setup({
    render = "background",
    enable_hex = true,
    enable_short_hex = true,
})

vim.cmd [[
  highlight Normal guibg=NONE ctermbg=NONE
  highlight NormalNC guibg=NONE ctermbg=NONE
  highlight SignColumn guibg=NONE ctermbg=NONE
  highlight EndOfBuffer guibg=NONE ctermbg=NONE
  highlight LineNr guibg=NONE ctermbg=NONE
  highlight FoldColumn guibg=NONE ctermbg=NONE
]]
