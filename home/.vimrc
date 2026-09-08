set tabstop=4
set softtabstop=0
set shiftwidth=4
set noexpandtab
set textwidth=0
set wrapmargin=0
set mouse=a
set ttymouse=sgr
set nospell
set incsearch
set nowrap
set number
set signcolumn=yes
set updatetime=250
set noswapfile
set autoread
set ruler
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

let mapleader = ' '
let g:fzf_layout = { 'window': { 'width': 0.80, 'height': 0.85 } }
let g:fzf_vim = { 'preview_window': ['right,50%,<70(up,40%)', 'ctrl-/'] }
if executable('rg')
    let $FZF_DEFAULT_COMMAND = "rg --files --hidden -g '!.git'"
endif

nnoremap <silent> <leader><space> :Files<CR>
nnoremap <silent> <leader>ff :Files<CR>
nnoremap <silent> <leader>/ :RG<CR>
nnoremap <silent> <leader>sg :RG<CR>
nnoremap <silent> <leader>fb :Buffers<CR>
nnoremap <silent> <leader>fr :History<CR>
nnoremap <silent> <leader>sh :Helptags<CR>

let g:gitgutter_map_keys = 0
nmap <silent> ]h <Plug>(GitGutterNextHunk)
nmap <silent> [h <Plug>(GitGutterPrevHunk)
nmap <silent> <leader>ghs <Plug>(GitGutterStageHunk)
xmap <silent> <leader>ghs <Plug>(GitGutterStageHunk)
nmap <silent> <leader>ghr <Plug>(GitGutterUndoHunk)
nmap <silent> <leader>ghp <Plug>(GitGutterPreviewHunk)
nnoremap <silent> <leader>gb :Git blame<CR>
nnoremap <silent> <leader>gs :Git<CR>
nnoremap <silent> <leader>gd :Gvdiffsplit<CR>
nnoremap <silent> <leader>gf :0Gclog<CR>
nnoremap <silent> <leader>gg :Git log --oneline<CR>
