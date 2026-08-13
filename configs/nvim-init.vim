" Neovim config — works on macOS and Linux

" --- Plugins ----------------------------------------------------------------
" Bootstrap vim-plug on first launch, then install everything.
let s:plug = stdpath('data') . '/site/autoload/plug.vim'
if empty(glob(s:plug))
  silent execute '!curl -fLo ' . shellescape(s:plug) . ' --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  " Source it directly: autoload does not pick up a file created this session.
  execute 'source ' . fnameescape(s:plug)
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin(stdpath('data') . '/plugged')
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'christoomey/vim-tmux-navigator'
Plug 'editorconfig/editorconfig-vim'
Plug 'preservim/nerdtree', { 'on': 'NERDTreeToggle' }
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'morhetz/gruvbox'
call plug#end()

" --- Appearance -------------------------------------------------------------
set termguicolors
silent! colorscheme gruvbox
set background=dark

set number
set relativenumber
set cursorline
set signcolumn=yes
set scrolloff=5

let g:airline_powerline_fonts = 1
let g:airline_theme = 'gruvbox'

" --- Editing ----------------------------------------------------------------
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set autoread
set hidden
set noswapfile
set nobackup
set splitright
set splitbelow
set mouse=a
set clipboard+=unnamedplus

" Case-insensitive search unless the pattern has a capital letter.
set ignorecase
set smartcase

" Persistent undo (neovim creates and manages the undo directory itself).
set undofile

" Reopen files where you left off.
autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" Word list used for <C-x><C-k> completion.
set dictionary+=~/.words

" --- Key bindings -----------------------------------------------------------
let mapleader = ','

nnoremap <C-n> :NERDTreeToggle<CR>
nnoremap <C-p> :Files<CR>
nnoremap <C-f> :Rg<CR>
nnoremap <Leader>b :Buffers<CR>
nnoremap <Leader>s :%s/\<<C-r><C-w>\>/
nnoremap <Leader><Space> :nohlsearch<CR>
