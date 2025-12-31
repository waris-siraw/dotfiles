-- =========================
-- NEOVIM GRUVBOX DARK
-- =========================

-- Enable true colors
vim.opt.termguicolors = true
vim.opt.background = "dark"

-- vim-plug (still works fine)
vim.cmd([[
  call plug#begin('~/.local/share/nvim/plugged')

  Plug 'ellisonleao/gruvbox.nvim'

  call plug#end()
]])

-- Set colorscheme
vim.cmd("colorscheme gruvbox")

-- Disable mouse
vim.opt.mouse = ""

-- Use system clipboard
vim.opt.clipboard = "unnamedplus"

