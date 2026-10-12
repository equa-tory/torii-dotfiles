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
--o.clipboard = "wl-clipboard"
o.splitright = true
o.splitbelow = true

-- Shortcuts
local o = vim.keymap
o.set("n", "<C-_>", "gcc", { remap = true })
o.set("x", "<C-_>", "gc", { remap = true })
o.set("n", "<C-/>", "gcc", { remap = true })
o.set("x", "<C-/>", "gc", { remap = true })
o.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
o.set("n", "U", "<C-r>", { desc = "Redo" })

o.set("n", "<leader>?", function()
  require("telescope.builtin").find_files({
    cwd = vim.fn.stdpath("config") .. "/cheatsheets",
    prompt_title = "Cheatsheets",
  })
end, { desc = "Cheatsheets" })


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
    config = function() vim.cmd.colorscheme("catppuccin-mocha") end,
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
