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
" Context around the cursor: without it a jump to a definition or reference
" lands on the last visible line. sidescroll=1 scrolls a column at a time
" instead of the default half screen, which 'nowrap' makes reachable.
set scrolloff=5
set sidescrolloff=8
set sidescroll=1
set splitbelow
set splitright
" The default dashes for diff fillers and fold padding read as content.
set fillchars+=vert:│,fold:\ ,diff:·
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
" unnamedplus needs an X11 or Wayland build; macOS has +clipboard without either,
" and there * and + are the same pasteboard, so unnamed is equivalent.
if has('unnamedplus')
    set clipboard=unnamedplus
elseif has('clipboard')
    set clipboard=unnamed
endif

set diffopt+=context:10
" Vertical everywhere, so :Gdiffsplit and :Git difftool match :Gvdiffsplit.
set diffopt+=vertical
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

" Closes a transient view in one keypress, diffs included. Fugitive's summary,
" pager and blame buffers carry their own gq, which does more than close --
" blame restores the window it was opened from -- so defer to it. The lookup is
" at keypress because packages load after this file. Diff blobs have no gq.
" bdelete covers the last window, where close raises E444.
function! s:CloseView() abort
    if get(maparg('gq', 'n', 0, 1), 'buffer', 0)
        normal gq
        return
    endif

    if !&diff
        if winnr('$') > 1
            close
        else
            bdelete
        endif
        return
    endif

    let l:blobs = []
    let l:copies = []
    for l:nr in range(1, winnr('$'))
        if !getwinvar(l:nr, '&diff')
            continue
        endif
        if bufname(winbufnr(l:nr)) =~# '^fugitive://'
            call add(l:blobs, win_getid(l:nr))
        else
            call add(l:copies, win_getid(l:nr))
        endif
    endfor

    " Tabs opened for a diff go with it: ours carry the flag, and fugitive's O
    " and :Git difftool -y leave a tab of nothing but historical blobs.
    if tabpagenr('$') > 1 && (get(t:, 'vimrc_diff_tab', 0)
                \ || (empty(l:copies) && len(l:blobs) == winnr('$')))
        tabclose
        return
    endif

    " Otherwise every window taking part goes, blobs first so a working copy is
    " what survives once only one window may remain.
    diffoff!
    for l:id in l:blobs + l:copies
        if winnr('$') > 1 && win_id2win(l:id)
            execute win_id2win(l:id) . 'close'
        endif
    endfor
    " Closing another window fires no WinEnter here, so release q now.
    call s:DiffQuitKey()
endfunction

" Diffs get a tab of their own, so opening one never disturbs the layout you
" were working in and q can take the whole thing away. The caller runs its diff
" command afterwards, inside the new tab.
function! s:DiffTab() abort
    tab split
    let t:vimrc_diff_tab = 1
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

" A location list belongs to one window, so the getwininfo() scan used above
" would also match a list belonging to some other window.
function! s:ToggleLoclist() abort
    if getloclist(0, {'winid': 0}).winid
        lclose
    elseif empty(getloclist(0))
        echo 'No location list'
    else
        lopen
    endif
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

" TypeScript 7 is a native binary with its own LSP mode and no tsserver.js, so
" typescript-language-server cannot drive it; TypeScript 6 and older have no
" --lsp. Homebrew and Arch both link tsc into the package's bin/, so the version
" is in the package.json beside it, which costs no process at startup.
function! s:TypescriptServer() abort
    let l:tsc = exepath('tsc')
    if !empty(l:tsc)
        let l:pkg = fnamemodify(resolve(l:tsc), ':h:h') . '/package.json'
        if filereadable(l:pkg)
            let l:ver = get(json_decode(join(readfile(l:pkg), "\n")), 'version', '0')
            if str2nr(l:ver) >= 7
                return {'path': 'tsc', 'args': ['--lsp', '--stdio']}
            endif
        endif
    endif
    return {'path': 'typescript-language-server', 'args': ['--stdio']}
endfunction

" Replacements for retrobox colors that reach outside its own palette. The gui
" values are gruvbox shades; the cterm ones approximate them for a terminal
" without 24-bit color.
function! s:Highlights() abort
    " A shade above the background rather than a line across it. The background
    " is retrobox's, which already matches Normal.
    highlight VertSplit   guifg=#3c3836 ctermfg=237
    highlight VertSplitNC guifg=#32302f ctermfg=236

    " retrobox pins a cream foreground over changed lines, hiding the syntax
    " colors underneath, and puts DiffText on saturated teal. DiffTextAdd marks
    " text only the new side has, which 'diffopt' inline:char isolates.
    highlight DiffAdd     guifg=NONE guibg=#26331f ctermfg=NONE ctermbg=22
    highlight DiffChange  guifg=NONE guibg=#3a3529 ctermfg=NONE ctermbg=237
    highlight DiffText    guifg=NONE guibg=#4d4632 ctermfg=NONE ctermbg=58
    highlight DiffTextAdd guifg=NONE guibg=#3b4c2c ctermfg=NONE ctermbg=28
    " Filler lines hold no text, so the foreground is the fill character alone.
    highlight DiffDelete  guifg=#503c34 guibg=#2b1e1a ctermfg=238 ctermbg=52

    " The diff syntax, which fugitive's status, log and commit views use,
    " defaults to pure red and lime green.
    highlight Added   guifg=#a9b665 ctermfg=107
    highlight Changed guifg=#d8a657 ctermfg=179
    highlight Removed guifg=#ea6962 ctermfg=167

    " gitgutter takes its sign colors from the Diff* foregrounds, NONE above,
    " which would leave all three signs alike.
    highlight GitGutterAdd    guifg=#a9b665 ctermfg=107
    highlight GitGutterChange guifg=#d8a657 ctermfg=179
    highlight GitGutterDelete guifg=#ea6962 ctermfg=167
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

    " A colorscheme load clears highlights and links; both are restored here.
    autocmd ColorScheme * call s:Highlights()
    autocmd ColorScheme * highlight! link gitLogDecoration Special

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

    " Collapse a commit to one line per file, which fugitive's foldtext renders
    " as a diffstat. The global foldminlines would leave short diffs expanded.
    autocmd FileType git setlocal foldmethod=syntax foldlevel=0 foldminlines=0
    " The stock git syntax colors oneline hashes, but not ref decorations.
    autocmd FileType git syntax match gitLogDecoration /\%(^\x\{7,\} \)\@<=([^)]*)/

    " Route fugitive's own diff keys through a fresh tab. The <Plug> targets are
    " its public interface, and reaching them needs a recursive nmap.
    autocmd FileType fugitive
                \ for s:key in ['dd', 'dv', 'ds', 'dh'] |
                \     execute 'nmap <buffer> <silent>' s:key
                \         ':<C-u>call <SID>DiffTab()<CR><Plug>fugitive:' . s:key |
                \ endfor
    " In a commit, <CR> opens the file in place, which loses the commit itself.
    " O is the same jump into a new tab. A commit object's name ends at the sha,
    " which distinguishes it from the log pager and from blobs under it.
    autocmd FileType git
                \ if bufname('%') =~# '^fugitive://.*//\x\{40\}$' |
                \     nmap <buffer> <CR> <Plug>fugitive:O |
                \ endif

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
" retrobox's 256-color fallbacks force one foreground across a diff, hiding the
" syntax colors its gui palette leaves alone. COLORTERM is the terminal's own
" claim of 24-bit support; tmux and screen need the sequences spelled out.
if has('termguicolors') && ($COLORTERM ==# 'truecolor' || $COLORTERM ==# '24bit')
    let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
    let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
    set termguicolors
endif

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

" Read when the package loads, which is after this file. Servers come from the
" system, so ignoreMissingServer keeps a machine without one quiet.
let g:lsp_options = {
    \ 'ignoreMissingServer': v:true,
    \ 'usePopupInCodeAction': v:true,
    \ 'completionMatcher': 'fuzzy',
    \ 'noNewlineInCompletion': v:true,
    \ }

" rootSearch finds the workspace root, nearest match winning: a per-package
" tsconfig would start a server per package and lose cross-package jumps, and a
" cargo workspace often sits below the repo root. A trailing slash means
" finddir(), so .git needs both spellings -- a directory in a clone, a file in
" a worktree. syncInit, which the plugin recommends for rust-analyzer, blocks
" Vim until initialize returns: tens of seconds on a large workspace. The
" TypeScript server depends on which TypeScript is installed; see above.
let g:lsp_servers = [
    \ {
    \   'name': 'clangd',
    \   'filetype': ['c', 'cpp'],
    \   'path': 'clangd',
    \   'args': ['--background-index'],
    \   'rootSearch': ['compile_commands.json', 'compile_flags.txt', '.clangd',
    \                  '.git/', '.git'],
    \ },
    \ {
    \   'name': 'pyright',
    \   'filetype': 'python',
    \   'path': 'pyright-langserver',
    \   'args': ['--stdio'],
    \   'rootSearch': ['pyproject.toml', 'setup.py', 'setup.cfg', '.git/', '.git'],
    \ },
    \ extend({
    \   'name': 'typescript',
    \   'filetype': ['typescript', 'typescriptreact', 'javascript',
    \                'javascriptreact'],
    \   'rootSearch': ['.git/', '.git'],
    \ }, s:TypescriptServer()),
    \ {
    \   'name': 'rust-analyzer',
    \   'filetype': 'rust',
    \   'path': 'rust-analyzer',
    \   'rootSearch': ['Cargo.toml'],
    \ },
    \ ]

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

" cutlass sends c, d, s and friends to the black hole, leaving m as the explicit
" cut, and noremap reaches the real operators. x and X stay unmapped so that
" cutlass, which loads after this file and skips mapped keys, claims them as
" "_x and "_X.
nnoremap m d
xnoremap m d
nnoremap mm dd
nnoremap M D
nnoremap <Del> "_x
xnoremap <Del> "_d

" cutlass takes m for cut, so marks move here. Nothing else may start with gm,
" or every mark would wait out 'timeoutlen'.
nnoremap gm m

nnoremap <silent> <Esc> :nohlsearch<CR>
nnoremap <silent> <leader>qq :qa<CR>
nnoremap <silent> <leader>us :setlocal spell! spell?<CR>
nnoremap <silent> <leader>uw :setlocal wrap! wrap?<CR>

" Completion
" 'noselect' leaves nothing highlighted until you move, so a first Tab has to
" both pick the top entry and accept it. noNewlineInCompletion then leaves <CR>
" a plain newline rather than a second accept key.
inoremap <expr> <Tab> pumvisible()
            \ ? (complete_info(['selected']).selected >= 0 ? "\<C-y>" : "\<C-n>\<C-y>")
            \ : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

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

" Quickfix and location list; LSP references and diagnostics land in the latter.
nnoremap <silent> [q :cprevious<CR>
nnoremap <silent> ]q :cnext<CR>
nnoremap <silent> <leader>xq :<C-u>call <SID>ToggleQuickfix()<CR>
nnoremap <silent> [l :lprevious<CR>
nnoremap <silent> ]l :lnext<CR>
nnoremap <silent> <leader>xl :<C-u>call <SID>ToggleLoclist()<CR>

" References
nnoremap <silent> yr :call <SID>Reference(0)<CR>
nnoremap <silent> yrr :call <SID>Reference(1)<CR>
" These also shadow the bare y operator, which would otherwise leave a pending
" r that replaces a character.
xnoremap <silent> yr :call <SID>Reference(0)<CR>
xnoremap <silent> yrr :call <SID>Reference(1)<CR>

" LSP. Unconditional rather than bound once a server attaches, which can take
" seconds on a large workspace; with no server the commands only warn. There is
" no severity-filtered pair to go with [d/]d, as :LspDiag takes no filter.
nnoremap <silent> gd :LspGotoDefinition<CR>
nnoremap <silent> gD :LspGotoDeclaration<CR>
nnoremap <silent> gI :LspGotoImpl<CR>
nnoremap <silent> gy :LspGotoTypeDef<CR>
nnoremap <silent> gr :LspShowReferences<CR>
nnoremap <silent> K :LspHover<CR>
nnoremap <silent> [d :LspDiag prev<CR>
nnoremap <silent> ]d :LspDiag next<CR>
nnoremap <silent> <leader>cd :LspDiag current<CR>
nnoremap <silent> <leader>xd :LspDiag show<CR>
nnoremap <silent> <leader>cr :LspRename<CR>
nnoremap <silent> <leader>ca :LspCodeAction<CR>
xnoremap <silent> <leader>ca :LspCodeAction<CR>
nnoremap <silent> <leader>uh :LspInlayHints toggle<CR>
" A clangd extension; the other servers just warn.
nnoremap <silent> <leader>ch :LspSwitchSourceHeader<CR>

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
nnoremap <silent> <leader>gd :<C-u>call <SID>DiffTab()<Bar>Gvdiffsplit<CR>
nnoremap <silent> <leader>gf :0Gclog<CR>
" Default to 200 commits; 1000<leader>gg requests more.
nnoremap <silent> <leader>gg :<C-u>execute
            \ 'Git log --oneline --decorate=short -n ' . (v:count ? v:count : 200)<CR>
