set tabstop=4
set softtabstop=0
set shiftwidth=4
set noexpandtab
set textwidth=0
set wrapmargin=0
set mouse=a
set ttymouse=sgr
set clipboard=unnamedplus
set spell
set incsearch
set nowrap
set number
set noswapfile
set fillchars+=vert:│
syntax on

let &t_EI = "\<Esc>[2 q"
let &t_SI = "\<Esc>[6 q"
let &t_ti .= "\<Esc>[2 q"
let &t_te .= "\<Esc>[0 q"

let g:python_recommended_style = 0
filetype plugin indent on

augroup vimrc
    autocmd!
    autocmd FileType * setlocal textwidth=0 wrapmargin=0
    autocmd ColorScheme * highlight! link VertSplit Normal
    autocmd ColorScheme * highlight! link VertSplitNC Normal
augroup END

colorscheme habamax
