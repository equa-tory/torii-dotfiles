-- Neovim 0.11+ config: lazy.nvim, LSP, completion, treesitter, UI polish
vim.g.mapleader = " "

local o = vim.opt
o.number = true
o.relativenumber = true
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.ignorecase = true
o.smartcase = true
o.termguicolors = true
o.signcolumn = "yes"
o.cursorline = true
o.scrolloff = 8
o.updatetime = 250
o.undofile = true
-- yank / delete / paste go through the system clipboard (so a yank can be pasted anywhere with Alt+V), when there is one:
-- wl-copy (Wayland), pbcopy (macOS), xclip, or the terminal itself over ssh (OSC 52)
if vim.fn.executable("wl-copy") == 1 or vim.fn.executable("pbcopy") == 1 or vim.fn.executable("xclip") == 1
  or vim.env.SSH_TTY then
  o.clipboard = "unnamedplus"
end
o.splitright = true
o.splitbelow = true

-- Shortcuts
local o = vim.keymap
o.set("n", "<C-_>", "gcc", { remap = true })
o.set("x", "<C-_>", "gc", { remap = true })
o.set("n", "<C-/>", "gcc", { remap = true })
o.set("x", "<C-/>", "gc", { remap = true })
o.set("n", "<leader>/", "gcc", { remap = true, desc = "Comment line" })
o.set("x", "<leader>/", "gc", { remap = true, desc = "Comment selection" })
o.set({ "n", "x" }, ";", ":", { desc = "Command line without Shift" })
-- <leader>= makes the buffer (or the selection) look normal: a one-line JSON / minified code / run-together text becomes
-- readable. prettier when it is installed, jq for JSON, the language server's formatter, xmllint for xml / html, text is
-- re-wrapped at 80 columns, anything else is re-indented.
local function tidy(visual)
  local ft, buf = vim.bo.filetype, vim.api.nvim_get_current_buf()
  local function filter(cmd)
    local range = visual and "'<,'>" or "%"
    vim.cmd(range .. "!" .. cmd)
  end
  local web = { javascript = 1, typescript = 1, javascriptreact = 1, typescriptreact = 1, css = 1, scss = 1, html = 1,
                json = 1, jsonc = 1, markdown = 1, yaml = 1 }
  if web[ft] and vim.fn.executable("prettier") == 1 and not visual then
    filter("prettier --stdin-filepath " .. vim.fn.shellescape(vim.api.nvim_buf_get_name(buf) ~= "" and vim.api.nvim_buf_get_name(buf) or "x." .. ft))
  elseif (ft == "json" or ft == "jsonc") and vim.fn.executable("jq") == 1 then
    filter("jq .")
  elseif (ft == "json" or ft == "jsonc") and vim.fn.executable("python3") == 1 then
    filter("python3 -m json.tool")
  elseif #vim.lsp.get_clients({ bufnr = buf, method = "textDocument/formatting" }) > 0 then
    vim.lsp.buf.format({ async = false, range = visual and { start = vim.api.nvim_buf_get_mark(0, "<"), ["end"] = vim.api.nvim_buf_get_mark(0, ">") } or nil })
  elseif (ft == "xml" or ft == "html") and vim.fn.executable("xmllint") == 1 then
    filter(ft == "html" and "xmllint --html --format - 2>/dev/null" or "xmllint --format -")
  elseif ft == "" or ft == "text" or ft == "markdown" or ft == "gitcommit" then
    vim.opt_local.textwidth = 80
    vim.cmd(visual and "normal! gvgq" or "normal! gggqG")
  else
    vim.cmd(visual and "normal! gv=" or "normal! gg=G``")
  end
end
o.set("n", "<leader>=", function() tidy(false) end, { desc = "Format: make the buffer look normal" })
o.set("x", "<leader>=", function() vim.cmd("normal! \27"); tidy(true) end, { desc = "Format: make the selection look normal" })

o.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
o.set("n", "U", "<C-r>", { desc = "Redo" })

o.set("n", "<leader>?", function()
  require("telescope.builtin").find_files({
    cwd = vim.fn.stdpath("config") .. "/cheatsheets",
    prompt_title = "Cheatsheets",
  })
end, { desc = "Cheatsheets" })

-- Leaving a file you only touched (a space typed and deleted again) is not an unsaved change:
-- when the text equals the file on disk, drop the modified flag before :q checks it.
vim.api.nvim_create_autocmd("QuitPre", {
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(buf)
    if not vim.bo[buf].modified or vim.bo[buf].buftype ~= "" or name == "" or vim.fn.filereadable(name) == 0 then return end
    local disk = vim.fn.readfile(name)
    local text = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if table.concat(disk, "\n") == table.concat(text, "\n") then
      vim.bo[buf].modified = false
    end
  end,
})

-- html: a line with only "!" becomes the default page template
local html_template = {
  "<!DOCTYPE html>",
  '<html lang="en">',
  "<head>",
  '  <meta charset="UTF-8">',
  '  <meta name="viewport" content="width=device-width, initial-scale=1.0">',
  "  <title></title>",
  "</head>",
  "<body>",
  "  ",
  "</body>",
  "</html>",
}
vim.api.nvim_create_autocmd("TextChangedI", {
  pattern = { "*.html", "*.htm" },
  callback = function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    if vim.api.nvim_get_current_line() ~= "!" then return end
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, html_template)
    vim.api.nvim_win_set_cursor(0, { row + 8, 2 })      -- inside <body>
  end,
})

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- Theme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function() require("torii_theme").apply() end,
  },

  -- Syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "python", "c_sharp", "c", "cpp", "javascript", "typescript",
          "json", "html", "css", "lua", "vim", "vimdoc", "bash", "markdown",
        },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },
  { "HiPhish/rainbow-delimiters.nvim" },
  { "lukas-reineke/indent-blankline.nvim", main = "ibl",
    opts = { scope = { enabled = false } } },
  { "echasnovski/mini.indentscope", version = false, opts = { symbol = "│" } },
  { "catgoose/nvim-colorizer.lua", opts = {} },

  -- Language servers
  { "mason-org/mason.nvim", opts = {} },
  { "neovim/nvim-lspconfig" },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig", "saghen/blink.cmp" },
    config = function()
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })
      require("mason-lspconfig").setup({
        ensure_installed = {
          "pyright",   -- python
          "omnisharp", -- c#
          "clangd",    -- c / c++
          "ts_ls",     -- javascript / typescript
          "jsonls",    -- json
          "html",
          "cssls",
          "lua_ls",
        },
      })
    end,
  },

  -- Autocompletion
  {
    "saghen/blink.cmp",
    version = "1.*",
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = {
      keymap = { preset = "super-tab" },
      completion = { documentation = { auto_show = true } },
      signature = { enabled = true },
    },
  },
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },

  -- Animations
  { "sphamba/smear-cursor.nvim", opts = {} },
  { "echasnovski/mini.animate", version = false, opts = {} },
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
    opts = {},
  },

  -- Quality of life
  { "nvim-tree/nvim-web-devicons" },
  { "nvim-lualine/lualine.nvim", opts = {} },
  { "lewis6991/gitsigns.nvim", opts = {} },
  { "folke/which-key.nvim", event = "VeryLazy", opts = {} },
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
    },
  },
  { "ThePrimeagen/vim-be-good" },
  { "brenoprata10/nvim-highlight-colors" },
})

-- LSP keymaps (K, grn, gra, grr, [d, ]d already exist by default in 0.11)
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local map = function(keys, fn, desc)
      vim.keymap.set("n", keys, fn, { buffer = ev.buf, desc = desc })
    end
    map("gd", vim.lsp.buf.definition, "Go to definition")
    map("<leader>rn", vim.lsp.buf.rename, "Rename")
    map("<leader>ca", vim.lsp.buf.code_action, "Code action")
    map("<leader>f", function() vim.lsp.buf.format({ async = true }) end, "Format")
  end,
})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" }, workspaceDelay = -1 },
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
    },
  },
})


-- Floating Terminal Panel
local term = { buf = nil, win = nil }

local function toggle_terminal()
  -- already open: hide it (the shell keeps running)
  if term.win and vim.api.nvim_win_is_valid(term.win) then
    vim.api.nvim_win_hide(term.win)
    term.win = nil
    return
  end

  local fresh = not (term.buf and vim.api.nvim_buf_is_valid(term.buf))
  if fresh then term.buf = vim.api.nvim_create_buf(false, true) end

  local w = math.floor(vim.o.columns * 0.6)
  local h = math.floor(vim.o.lines * 0.4)
  term.win = vim.api.nvim_open_win(term.buf, true, {
    relative = "editor", width = w, height = h,
    col = math.floor((vim.o.columns - w) / 2),
    row = math.floor((vim.o.lines - h) / 2),
    style = "minimal", border = "rounded",
  })

  if fresh then
    vim.fn.jobstart(vim.o.shell, { term = true })
    -- when you type `exit`, clean up so the next toggle starts a new shell
    vim.api.nvim_create_autocmd("TermClose", {
      buffer = term.buf,
      callback = function()
        local buf = term.buf
        term.buf, term.win = nil, nil
        vim.schedule(function()
          if buf and vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end)
      end,
    })
  end
  vim.cmd("startinsert")
end

vim.keymap.set("n", "<leader>i", toggle_terminal, { desc = "Floating terminal" })
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Leave terminal mode" })
