-- Neovim config — works on macOS and Linux. Needs neovim 0.11+.
-- One file on purpose: everything you can change is visible from here.

vim.g.mapleader = ','
vim.g.maplocalleader = ','

-- ── Options ───────────────────────────────────────────────────────────────
local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = 'yes'
opt.scrolloff = 5
opt.termguicolors = true

opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

opt.ignorecase = true -- case-insensitive search...
opt.smartcase = true  -- ...unless the pattern has a capital letter
opt.inccommand = 'split'

opt.splitright = true
opt.splitbelow = true
opt.swapfile = false
opt.backup = false
opt.undofile = true -- neovim creates and manages the undo directory itself
opt.updatetime = 250
opt.mouse = 'a'
opt.confirm = true
opt.dictionary:append(vim.fn.expand('~/.words'))

-- Share the system clipboard, but do it after startup so a slow clipboard
-- provider cannot delay opening a file.
vim.schedule(function()
  opt.clipboard = 'unnamedplus'
end)

-- Reopen files where you left off.
vim.api.nvim_create_autocmd('BufReadPost', {
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(args.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Briefly highlight whatever you just yanked.
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function() (vim.hl or vim.highlight).on_yank() end,
})

-- ── Plugins ───────────────────────────────────────────────────────────────
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', lazypath,
  })
end
opt.rtp:prepend(lazypath)

require('lazy').setup({
  -- Theme
  {
    'ellisonleao/gruvbox.nvim',
    priority = 1000,
    config = function()
      require('gruvbox').setup({ contrast = 'hard' })
      vim.cmd.colorscheme('gruvbox')
    end,
  },

  { 'nvim-lualine/lualine.nvim', opts = { options = { theme = 'gruvbox', globalstatus = true } } },

  -- Git
  { 'lewis6991/gitsigns.nvim', opts = {} },
  { 'tpope/vim-fugitive', cmd = { 'Git', 'Gdiffsplit', 'Gblame' } },

  -- Editing
  { 'kylechui/nvim-surround', opts = {} },
  { 'windwp/nvim-autopairs', event = 'InsertEnter', opts = {} },
  { 'folke/which-key.nvim', event = 'VeryLazy', opts = {} },

  -- Ctrl-h/j/k/l moves across neovim splits and tmux panes alike.
  { 'christoomey/vim-tmux-navigator' },

  -- File tree, kept on Ctrl-n out of muscle memory
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = { view = { width = 34 } },
  },

  -- Fuzzy finding, backed by the same fzf binary the shell uses
  {
    'ibhagwan/fzf-lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = { winopts = { height = 0.85, width = 0.85 } },
  },

  -- Syntax and indentation
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main', -- the rewrite; the old master branch has a different API
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').install({
        'bash', 'c', 'diff', 'dockerfile', 'go', 'hcl', 'json', 'lua', 'make',
        'markdown', 'proto', 'python', 'query', 'regex', 'toml', 'vim', 'vimdoc', 'yaml',
      })

      -- Turn on highlighting for any filetype that has a parser installed.
      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },

  -- LSP. mason installs the servers, so there is nothing to install by hand.
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      { 'j-hui/fidget.nvim', opts = {} },
    },
    config = function()
      require('mason-lspconfig').setup({
        ensure_installed = { 'lua_ls', 'ruff', 'bashls', 'yamlls' },
      })

      vim.lsp.config('lua_ls', {
        settings = { Lua = { diagnostics = { globals = { 'vim' } } } },
      })

      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local function map(keys, fn, desc)
            vim.keymap.set('n', keys, fn, { buffer = args.buf, desc = 'LSP: ' .. desc })
          end
          map('gd', vim.lsp.buf.definition, 'goto definition')
          map('gr', vim.lsp.buf.references, 'references')
          map('gI', vim.lsp.buf.implementation, 'goto implementation')
          map('K', vim.lsp.buf.hover, 'hover docs')
          map('<leader>rn', vim.lsp.buf.rename, 'rename')
          map('<leader>ca', vim.lsp.buf.code_action, 'code action')
          map('<leader>e', vim.diagnostic.open_float, 'line diagnostics')
        end,
      })

      vim.diagnostic.config({
        virtual_text = true,
        severity_sort = true,
        float = { border = 'rounded' },
      })
    end,
  },

  -- Completion
  {
    'saghen/blink.cmp',
    version = '*',
    opts = {
      keymap = { preset = 'default' },
      sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
      completion = { documentation = { auto_show = true } },
    },
  },

  -- Formatting. ruff replaces the old black and flake8 pair.
  {
    'stevearc/conform.nvim',
    opts = {
      format_on_save = { timeout_ms = 1000, lsp_format = 'fallback' },
      formatters_by_ft = {
        lua = { 'stylua' },
        python = { 'ruff_organize_imports', 'ruff_format' },
        sh = { 'shfmt' },
      },
    },
  },
}, {
  install = { colorscheme = { 'gruvbox' } },
  change_detection = { notify = false },
})

-- ── Key bindings ──────────────────────────────────────────────────────────
local map = vim.keymap.set
local fzf = require('fzf-lua')

map('n', '<C-n>', '<cmd>NvimTreeToggle<cr>', { desc = 'Toggle file tree' })
map('n', '<C-p>', fzf.files, { desc = 'Find files' })
map('n', '<C-f>', fzf.live_grep, { desc = 'Search file contents' })
map('n', '<leader>b', fzf.buffers, { desc = 'Switch buffer' })
map('n', '<leader>/', fzf.blines, { desc = 'Search this buffer' })
map('n', '<leader>d', fzf.diagnostics_workspace, { desc = 'Diagnostics' })

-- Replace the word under the cursor.
map('n', '<leader>s', [[:%s/\<<C-r><C-w>\>/]], { desc = 'Replace word under cursor' })
map('n', '<leader><space>', '<cmd>nohlsearch<cr>', { desc = 'Clear search highlight' })
map('n', '<leader>g', '<cmd>Git<cr>', { desc = 'Git status' })

-- Keep the cursor centred when paging and jumping through search results.
map('n', '<C-d>', '<C-d>zz')
map('n', '<C-u>', '<C-u>zz')
map('n', 'n', 'nzzzv')
map('n', 'N', 'Nzzzv')

-- Move the selection up and down.
map('v', 'J', ":m '>+1<cr>gv=gv")
map('v', 'K', ":m '<-2<cr>gv=gv")

map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Leave terminal mode' })
