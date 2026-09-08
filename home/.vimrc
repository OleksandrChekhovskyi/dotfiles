" -----------------------------------------------------------------------------
" Options
" -----------------------------------------------------------------------------
" Hard tabs; softtabstop=0 keeps <BS> deleting one tab rather than spaces.
set tabstop=4
set softtabstop=0
set shiftwidth=4
set noexpandtab
set textwidth=0
set wrapmargin=0

set incsearch
set hlsearch
set ignorecase
set smartcase
set nospell

set number
set cursorline
set nowrap
set ruler
set display=truncate
set splitbelow
set splitright
set fillchars+=vert:│
" Always reserved, so gitgutter signs never shift the text sideways.
set signcolumn=yes

set mouse=a
" sgr encoding: the older xterm2 reporting breaks past column 223.
set ttymouse=sgr

set history=1000
" First <Tab> completes the longest common prefix and shows the menu; later
" ones cycle through matches.
set wildmode=longest:full,full

" How long an ambiguous mapping waits for the next key: visual y must rule out
" yr before it can act.
set timeoutlen=300
" Key codes time out separately, so <Esc> is never held for timeoutlen.
set ttimeout
set ttimeoutlen=50
" Drives CursorHold: gitgutter's sign refresh and the checktime autocommand.
set updatetime=250

set noswapfile
set autoread
" Undo files hold buffer text, and with noswapfile they are the only recovery.
set undodir=~/.vim/undo
set undofile
if !isdirectory(expand(&undodir))
    call mkdir(expand(&undodir), 'p', 0700)
endif

" Safe only because cutlass sends deletes and changes to the black hole.
if has('unnamedplus')
    set clipboard=unnamedplus
endif

set diffopt+=context:10
set foldminlines=10

" -----------------------------------------------------------------------------
" Filetypes and syntax
" -----------------------------------------------------------------------------
" syntax on restores default highlighting, so it has to precede the colorscheme.
filetype plugin indent on
syntax on

" -----------------------------------------------------------------------------
" Terminal
" -----------------------------------------------------------------------------
" DECSCUSR shapes: block in normal mode, bar in insert. t_ti applies the shape
" on entry, t_te restores the terminal default on exit.
let &t_EI = "\<Esc>[2 q"
let &t_SI = "\<Esc>[6 q"
let &t_ti .= "\<Esc>[2 q"
let &t_te .= "\<Esc>[0 q"

" Vim leaves these empty for TERM=tmux-256color, so it never asks the terminal
" for focus events and FocusGained never fires. tmux needs focus-events on too.
let &t_fe = "\<Esc>[?1004h"
let &t_fd = "\<Esc>[?1004l"

" -----------------------------------------------------------------------------
" Functions
" -----------------------------------------------------------------------------
" Staging outside Vim changes the index, which nothing polls. gitgutter already
" re-diffs on FocusGained; only fugitive's summary needs telling, and telling it
" unconditionally would repeat that work through the User FugitiveChanged event.
function! s:RefreshFugitive() abort
    if !exists('*FugitiveDidChange')
        return
    endif
    for l:info in getbufinfo({'bufloaded': 1})
        if getbufvar(l:info.bufnr, '&filetype') ==# 'fugitive'
            call FugitiveDidChange()
            return
        endif
    endfor
endfunction

" Closes a transient view. Fugitive's summary, pager and blame buffers carry
" their own gq, which does more than close -- blame restores the window it was
" opened from -- so defer to it. The lookup is at keypress because packages load
" after this file. Diff blobs have no gq. bdelete covers the last window, where
" close raises E444.
function! s:CloseView() abort
    if get(maparg('gq', 'n', 0, 1), 'buffer', 0)
        normal gq
        return
    endif
    let l:on_blob = bufname('%') =~# '^fugitive://'
    let l:in_diff = &diff
    if l:in_diff
        diffoff!
    endif
    " From the working-copy side the blob is what should go; a merge has two.
    if l:in_diff && !l:on_blob
        for l:nr in range(winnr('$'), 1, -1)
            if bufname(winbufnr(l:nr)) =~# '^fugitive://'
                execute l:nr . 'close'
            endif
        endfor
        " Closing another window fires no WinEnter here, so release q now.
        call s:DiffQuitKey()
        return
    endif
    if winnr('$') > 1
        close
    else
        bdelete
    endif
endfunction

" The working-copy side of a diff is an ordinary buffer, where q must stay the
" record-macro key. Bind it only while a fugitive diff is on screen; the flag
" keeps the teardown from stripping a q that a filetype autocommand installed.
function! s:DiffQuitKey() abort
    let l:in_diff = 0
    if &diff
        for l:nr in range(1, winnr('$'))
            if bufname(winbufnr(l:nr)) =~# '^fugitive://'
                let l:in_diff = 1
                break
            endif
        endfor
    endif

    if l:in_diff
        let b:vimrc_diff_quit = 1
        nnoremap <buffer> <silent> q :<C-u>call <SID>CloseView()<CR>
    elseif get(b:, 'vimrc_diff_quit', 0)
        unlet b:vimrc_diff_quit
        silent! nunmap <buffer> q
    endif
endfunction

" <C-u> in the callers drops the range Vim builds from a count, which v:count1
" still reports here.
function! s:ResizeWindow(delta, vertical) abort
    let l:amount = a:delta * v:count1
    let l:prefix = a:vertical ? 'vertical resize ' : 'resize '
    execute l:prefix . (l:amount > 0 ? '+' . l:amount : l:amount)
endfunction

" getwininfo() reports quickfix=1 for location lists too; loclist tells them
" apart, and only the quickfix window should toggle here.
function! s:ToggleQuickfix() abort
    for l:win in getwininfo()
        if l:win.quickfix && !l:win.loclist
            cclose
            return
        endif
    endfor
    botright copen
endfunction

" File location for sharing, relative to the git work tree so it means the same
" in another checkout, or to the working directory outside one. 5yrr spans a
" range of lines.
function! s:Reference(lines) range abort
    let l:file = expand('%:p')
    if empty(l:file)
        return
    endif
    let l:root = trim(system('git -C ' . shellescape(fnamemodify(l:file, ':h'))
                \ . ' rev-parse --show-toplevel'))
    let l:path = (!v:shell_error && stridx(l:file, l:root . '/') == 0)
                \ ? l:file[len(l:root) + 1:]
                \ : fnamemodify(l:file, ':.')
    let l:ref = l:path
    if a:lines
        let l:ref .= a:firstline == a:lastline
                    \ ? ':' . a:firstline
                    \ : ':' . a:firstline . '-' . a:lastline
    endif
    " Vim without +clipboard rejects the + register outright.
    call setreg(has('clipboard') ? '+' : '"', l:ref)
    echo l:ref
endfunction

" -----------------------------------------------------------------------------
" Autocommands
" -----------------------------------------------------------------------------
augroup vimrc
    autocmd!
    autocmd FocusGained * call s:RefreshFugitive()

    " Filetype plugins impose their own textwidth (78 for gitcommit, text, ...),
    " overriding the global setting; never auto-wrap regardless.
    autocmd FileType * setlocal textwidth=0 wrapmargin=0

    " Seamless split borders. A colorscheme load clears highlight links, so they
    " have to be restored on every change.
    autocmd ColorScheme * highlight! link VertSplit Normal
    autocmd ColorScheme * highlight! link VertSplitNC Normal

    " autoread only reloads on :commands; checktime is what polls. Skip the
    " cmdline, and the command-line window, which reports normal mode here
    " yet rejects checktime with E11.
    autocmd FocusGained,BufEnter,CursorHold *
                \ if mode() !=# 'c' && empty(getcmdwintype()) | checktime | endif

    autocmd FileType qf,fugitive,fugitiveblame,git
                \ nnoremap <buffer> <silent> q :<C-u>call <SID>CloseView()<CR>
    " Diff blobs take the filetype of the file they hold, so match on the name.
    autocmd BufWinEnter fugitive://*
                \ nnoremap <buffer> <silent> q :<C-u>call <SID>CloseView()<CR>
    autocmd WinEnter,BufEnter * call s:DiffQuitKey()
    " <Esc> is otherwise inert in the command-line window.
    autocmd CmdwinEnter * nnoremap <buffer> <silent> <Esc> :quit<CR>

    " l1: align braces in "case X: {" with the case label. j1: inline lambdas.
    " (s/u0: indent unclosed parens one shiftwidth. ks: same for conditions.
    " m1: align closing parens with the opening line. cinkeys omits ":" to
    " avoid reindent churn while typing labels.
    autocmd FileType c,cpp setlocal cinoptions=l1,j1,(s,u0,ks,m1
    autocmd FileType c,cpp setlocal cinkeys=0{,0},0),0],0#,!^F,o,O,e
augroup END

" -----------------------------------------------------------------------------
" Appearance
" -----------------------------------------------------------------------------
" Triggers the ColorScheme autocommands above, so it has to follow them.
" retrobox reads &background as it loads.
set background=dark
colorscheme retrobox

" -----------------------------------------------------------------------------
" Plugin settings
" -----------------------------------------------------------------------------
let g:fzf_layout = { 'window': { 'width': 0.80, 'height': 0.85 } }
" Preview on the right, flipping above the list when narrower than 70 columns.
let g:fzf_vim = { 'preview_window': ['right,50%,<70(up,40%)', 'ctrl-/'] }
if executable('rg')
    let $FZF_DEFAULT_COMMAND = "rg --files --hidden -g '!.git'"
endif

let g:gitgutter_map_keys = 0

" -----------------------------------------------------------------------------
" Mappings
" -----------------------------------------------------------------------------
let mapleader = ' '

" A stray q should not silently start recording, so recording moves to Q, whose
" Ex mode remains on gQ. Nothing else may start with q, since a longer mapping
" such as q: would make every close wait out timeoutlen. The command-line
" window stays reachable through 'cedit', CTRL-F by default.
nnoremap q <Nop>
nnoremap Q q

" cutlass sends c, d, s and friends to the black hole, leaving x as the explicit
" cut, as in nvim-ide. noremap reaches the real operators, and defining them
" here claims the keys before cutlass loads, which skips keys already mapped.
" Single characters go with dl.
nnoremap x d
xnoremap x d
nnoremap xx dd
nnoremap X D
nnoremap <Del> "_x
xnoremap <Del> "_d

nnoremap <silent> <Esc> :nohlsearch<CR>
nnoremap <silent> <leader>qq :qa<CR>
nnoremap <silent> <leader>us :setlocal spell! spell?<CR>
nnoremap <silent> <leader>uw :setlocal wrap! wrap?<CR>

" Windows
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
nnoremap <silent> <leader>- :split<CR>
" A bare | would end the mapping, hence the escape; \ is its unshifted alias.
nnoremap <silent> <leader>\| :vsplit<CR>
nnoremap <silent> <leader>\ :vsplit<CR>
nnoremap <silent> <leader>wd <C-w>c
nnoremap <silent> <C-Up>    :<C-u>call <SID>ResizeWindow( 2, 0)<CR>
nnoremap <silent> <C-Down>  :<C-u>call <SID>ResizeWindow(-2, 0)<CR>
nnoremap <silent> <C-Left>  :<C-u>call <SID>ResizeWindow(-2, 1)<CR>
nnoremap <silent> <C-Right> :<C-u>call <SID>ResizeWindow( 2, 1)<CR>

" Buffers and tabs
nnoremap <silent> <S-h> :bprevious<CR>
nnoremap <silent> <S-l> :bnext<CR>
nnoremap <silent> [b :bprevious<CR>
nnoremap <silent> ]b :bnext<CR>
nnoremap <silent> <leader>bb :e #<CR>
nnoremap <silent> <leader><tab><tab> :tabnew<CR>
nnoremap <silent> <leader><tab>d :tabclose<CR>
nnoremap <silent> <leader><tab>o :tabonly<CR>
nnoremap <silent> <leader><tab>[ :tabprevious<CR>
nnoremap <silent> <leader><tab>] :tabnext<CR>
nnoremap <silent> <leader><tab>f :tabfirst<CR>
nnoremap <silent> <leader><tab>l :tablast<CR>
nnoremap <silent> [t :tabprevious<CR>
nnoremap <silent> ]t :tabnext<CR>

" Quickfix
nnoremap <silent> [q :cprevious<CR>
nnoremap <silent> ]q :cnext<CR>
nnoremap <silent> <leader>xq :<C-u>call <SID>ToggleQuickfix()<CR>

" References
nnoremap <silent> yr :call <SID>Reference(0)<CR>
nnoremap <silent> yrr :call <SID>Reference(1)<CR>
" These also shadow the bare y operator, which would otherwise leave a pending
" r that replaces a character.
xnoremap <silent> yr :call <SID>Reference(0)<CR>
xnoremap <silent> yrr :call <SID>Reference(1)<CR>

" Find
nnoremap <silent> <leader><space> :Files<CR>
nnoremap <silent> <leader>ff :Files<CR>
nnoremap <silent> <leader>/ :RG<CR>
nnoremap <silent> <leader>sg :RG<CR>
nnoremap <silent> <leader>fb :Buffers<CR>
nnoremap <silent> <leader>fr :History<CR>
nnoremap <silent> <leader>sh :Helptags<CR>
nnoremap <silent> <leader>sw :RG <C-r><C-w><CR>
nnoremap <silent> <leader>ss :BLines<CR>
nnoremap <silent> <leader>sS :Lines<CR>

" Git
" <Plug> targets need recursive nmap/xmap; nnoremap would not expand them.
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
