" =========================
" NEOVIM GRUVBOX DARK
" =========================

set termguicolors
set background=dark

call plug#begin('~/.local/share/nvim/plugged')

Plug 'ellisonleao/gruvbox.nvim'

call plug#end()

colorscheme gruvbox

set mouse=

set clipboard=unnamedplus
