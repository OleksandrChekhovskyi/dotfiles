-- Neovim config

--------------------------------------------------------------------------------
-- Bootstrap
--------------------------------------------------------------------------------
vim.loader.enable()

-- Prevent netrw loading after Neo-tree setup has cleared its directory autocmds.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

--------------------------------------------------------------------------------
-- Leader keys (must be set before loading plugins)
--------------------------------------------------------------------------------
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

--------------------------------------------------------------------------------
-- Vim options
--------------------------------------------------------------------------------
-- Tabs & indentation
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = false
vim.opt.smarttab = false
vim.opt.smartindent = true

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = false

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true

-- Appearance
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.wrap = false
vim.opt.textwidth = 0
vim.opt.fillchars:append({ eob = " " })
vim.opt.scrolloff = 5
vim.opt.sidescrolloff = 8
-- Avoid cursor-shaped redraw artifacts with tmux synchronized output on Nvim 0.12.3.
vim.opt.termsync = false

-- Splits
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Files
vim.opt.swapfile = false
vim.opt.undofile = true

-- Mouse
vim.opt.mouse = "a"

-- Auto-reload files changed outside Neovim (e.g. by external coding agents)
vim.opt.autoread = true

-- Spell
vim.opt.spell = false

-- Clipboard (cutlass keeps deletes and changes from overwriting it)
vim.opt.clipboard = "unnamedplus"

-- Timing
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300

-- Diff/Folding
vim.opt.diffopt:append("context:10")
vim.opt.foldminlines = 10

--------------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------------
-- Icons for the gutter signs and the statusline counts. The default status format would
-- print "<icon>:2", in no fixed severity order.
do
  local severity = vim.diagnostic.severity
  local icons = {
    [severity.ERROR] = "\xef\x81\x97", -- error circle with X
    [severity.WARN] = "\xef\x81\xb1", -- warning triangle
    [severity.INFO] = "\xef\x81\x9a", -- info circle
    [severity.HINT] = "\xef\x83\xab", -- lightbulb
  }
  local highlights = {
    [severity.ERROR] = "DiagnosticSignError",
    [severity.WARN] = "DiagnosticSignWarn",
    [severity.INFO] = "DiagnosticSignInfo",
    [severity.HINT] = "DiagnosticSignHint",
  }
  vim.diagnostic.config({
    signs = { text = icons },
    status = {
      format = function(counts)
        local parts = {}
        for level = severity.ERROR, severity.HINT do
          local count = counts[level]
          if count then
            table.insert(parts, ("%%#%s#%s %d"):format(highlights[level], icons[level], count))
          end
        end
        return table.concat(parts, " ")
      end,
    },
  })
end

--------------------------------------------------------------------------------
-- Statusline and messages
--------------------------------------------------------------------------------
-- With cmdheight=0, typing : raises 'cmdheight' to 1 while the cmdline is open, which
-- moves the statusline up a row; UI2 has no overlay cmdline.
vim.opt.laststatus = 3
vim.opt.cmdheight = 0

-- Messages go to a float above the statusline rather than growing the cmdline, shell
-- output to the pager. Nvim 0.12 reads msg.target, 0.13 reads targets.default. 0.13
-- rejects the 0.12 timeout keys, so the timeouts stay at their defaults.
require("vim._core.ui2").enable({
  msg = {
    target = "msg",
    targets = {
      default = "msg",
      shell_cmd = "pager",
      shell_out = "pager",
      shell_err = "pager",
    },
  },
})

-- With cmdheight=0, UI2 drops the mode, showcmd, ruler, and search count. The statusline
-- shows all but showcmd, whose pending keys would only flash by.
vim.opt.showmode = false
vim.opt.showcmd = false

local statusline_modes = {
  n = { "NORMAL", "StatusLineNormal" },
  i = { "INSERT", "StatusLineInsert" },
  R = { "REPLACE", "StatusLineReplace" },
  v = { "VISUAL", "StatusLineVisual" },
  V = { "V-LINE", "StatusLineVisual" },
  ["\22"] = { "V-BLOCK", "StatusLineVisual" },
  s = { "SELECT", "StatusLineVisual" },
  S = { "S-LINE", "StatusLineVisual" },
  ["\19"] = { "S-BLOCK", "StatusLineVisual" },
  c = { "COMMAND", "StatusLineCommand" },
  t = { "TERMINAL", "StatusLineTerminal" },
}

-- Centered in a fixed width, so that the rest of the line stays put across modes.
local function statusline_mode()
  local mode = statusline_modes[vim.api.nvim_get_mode().mode:sub(1, 1)] or statusline_modes.n
  local label, group = unpack(mode)
  local width = 8
  local pad = math.floor((width - #label) / 2)
  local text = (" "):rep(pad) .. label .. (" "):rep(width - #label - pad)
  return "%#" .. group .. "# " .. text .. " %*"
end

-- Special buffers have no file of their own, so they show the working directory's branch,
-- which keeps the line steady when moving between them and files.
local function statusline_branch()
  local head
  if vim.bo.buftype == "" then
    head = vim.b.gitsigns_head
  else
    head = vim.g.gitsigns_head
  end
  if not head or head == "" then
    return ""
  end
  -- Escaped, since the result is evaluated: Git allows names such as "%{luaeval(...)}".
  return "%#StatusLineBranch#\xee\x9c\xa5 " .. head:gsub("%%", "%%%%") .. "%*"
end

-- The icon bufferline and neo-tree show for the file. Special buffers get their filetype's
-- icon, if mini.icons has one other than its generic default.
local function statusline_icon()
  local name = vim.api.nvim_buf_get_name(0)
  local icon, group, is_default
  if vim.bo.buftype == "" then
    if name == "" then
      return ""
    end
    icon, group = MiniIcons.get("file", name)
  elseif vim.bo.filetype ~= "" then
    icon, group, is_default = MiniIcons.get("filetype", vim.bo.filetype)
  end
  if not icon or is_default then
    return ""
  end
  return "%#" .. group .. "#" .. icon .. "%* "
end

-- The exit code of a finished terminal job, which its buffer name does not show.
local function statusline_exit_code()
  if vim.bo.buftype ~= "terminal" or vim.bo.channel == 0 then
    return ""
  end
  local code = vim.api.nvim_get_chan_info(vim.bo.channel).exitcode
  return code and code >= 0 and (" [Exit: " .. code .. "]") or ""
end

-- "[current/total]" while search matches are highlighted. This is the count Nvim computes
-- for search commands ('shortmess' without "S"), as of the last n, N, *, or /: recounting
-- on every redraw would rescan the buffer on every cursor move.
local function statusline_search_count()
  if vim.v.hlsearch == 0 then
    return ""
  end
  local ok, count = pcall(vim.fn.searchcount, { recompute = false })
  if not ok or not count.total or count.total == 0 then
    return ""
  end
  -- Past 'maxsearchcount', both numbers stop at the limit + 1.
  local function capped(n)
    return count.incomplete == 2 and n > count.maxcount and (">" .. count.maxcount) or n
  end
  local current = count.incomplete == 1 and "?" or capped(count.current)
  return ("[%s/%s]"):format(current, capped(count.total))
end

-- Nvim keeps one count for all buffers, so recount on entering a buffer rather than show
-- the previous one's. Deferred until the buffer's cursor position has been restored. The
-- timeout bounds the scan in large files.
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("nvim-statusline-search-count", { clear = true }),
  callback = function()
    vim.schedule(function()
      if vim.v.hlsearch == 1 then
        pcall(vim.fn.searchcount, { recompute = true, timeout = 50 })
        vim.cmd.redrawstatus()
      end
    end)
  end,
})

-- Added, changed, and removed line counts from gitsigns, in its dimmed sign colors.
local function statusline_diff()
  local status = vim.b.gitsigns_status_dict
  if not status then
    return ""
  end
  local parts = {}
  for _, item in ipairs({
    { status.added, "+", "GitSignsAdd" },
    { status.changed, "~", "GitSignsChange" },
    { status.removed, "-", "GitSignsDelete" },
  }) do
    local count, sign, group = unpack(item)
    if count and count > 0 then
      table.insert(parts, "%#" .. group .. "#" .. sign .. count)
    end
  end
  return #parts > 0 and (table.concat(parts, " ") .. "%*") or ""
end

-- Screen column only, so tabs count as 'tabstop' spaces. Padded to the widest line number
-- and a three-digit column, so that moving the cursor does not shift the chunks before
-- it; %P is always three cells.
local function statusline_position()
  local width = #tostring(vim.api.nvim_buf_line_count(0)) + 4
  return "%-" .. width .. "(%l:%v%) %P"
end

local function statusline_join(chunks)
  local present = vim.tbl_filter(function(chunk) return chunk ~= "" end, chunks)
  return table.concat(present, "  ")
end

-- A global, since 'statusline' can call Lua only through v:lua. It has no timers, so an
-- idle Nvim stays idle. With laststatus=3 it describes the current window, floats
-- included. Special buffers show their raw names, which already say what they are:
-- term:// with the directory and command, diffview:// with the revision and path.
function _G.Statusline()
  local recording = vim.fn.reg_recording()
  return statusline_join({
    statusline_mode(),
    statusline_branch(),
    -- The %( %) group drops its leading space when there are no flags.
    "%<" .. statusline_icon() .. "%f%( %h%w%m%r%)" .. statusline_exit_code(),
  }) .. "%=" .. statusline_join({
    recording ~= "" and ("%#StatusLineRecording#@" .. recording .. "%*") or "",
    statusline_search_count(),
    vim.diagnostic.status(),
    statusline_diff(),
    statusline_position(),
  })
end
vim.opt.statusline = "%!v:lua.Statusline()"
-- The qf ftplugin would set a window-local statusline, replacing this one in quickfix.
vim.g.qf_disable_statusline = 1

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local indent_exclude_filetypes = {
  "fzf",
  "help",
  "neo-tree",
}

--- Check if cursor is inside a comment or string using treesitter highlight captures.
--- Language-agnostic: capture names (@comment, @string) are standardized across parsers.
local function in_comment_or_string()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  -- In insert mode the cursor is between characters; look one column back
  -- so we check the character we just typed, not the one ahead of it.
  if vim.api.nvim_get_mode().mode == "i" then
    col = col - 1
  end
  if col < 0 then
    return false
  end
  local ok, captures = pcall(vim.treesitter.get_captures_at_pos, 0, row - 1, col)
  if not ok or not captures then
    return false
  end
  for _, capture in ipairs(captures) do
    if capture.capture:find("^comment") or capture.capture:find("^string") then
      return true
    end
  end
  return false
end

--------------------------------------------------------------------------------
-- Plugins
--------------------------------------------------------------------------------

-- plugins.py installs the checkouts. Nvim sources "start" packages only after
-- init.lua, too late for the setup calls below.
vim.cmd("packloadall!")

if #vim.fn.globpath(vim.o.packpath, "pack/dotfiles/start/*", false, true) == 0 then
  error("no plugins installed; run ./plugins.py sync nvim in the dotfiles repo")
end

-- File icons; must precede the plugins that consume them.
require("mini.icons").setup({})
MiniIcons.mock_nvim_web_devicons()

-- Delete/change discard; m is the explicit cut. Cut sits on m, not x, so that
-- cutlass keeps x and X as single-character deletes into the black hole.
require("cutlass").setup({ cut_key = "m", override_del = true })

-- Detect indentation from existing buffers when no .editorconfig overrides it.
require("guess-indent").setup({
  auto_cmd = true,
  override_editorconfig = false,
  on_tab_options = {
    expandtab = false,
    softtabstop = 0,
    varsofttabstop = "",
  },
  on_space_options = {
    expandtab = true,
    tabstop = "detected",
    softtabstop = "detected",
    shiftwidth = "detected",
  },
})

local function disable_soft_backspace_for_tab_indent(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  if not vim.bo[buf].expandtab then
    vim.bo[buf].softtabstop = 0
    vim.bo[buf].varsofttabstop = ""
  end
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufFilePost", "FileType" }, {
  group = vim.api.nvim_create_augroup("nvim-tab-indent-backspace", { clear = true }),
  callback = function(event)
    local buf = event.buf
    vim.schedule(function()
      disable_soft_backspace_for_tab_indent(buf)
    end)
  end,
})

-- Color scheme
require("catppuccin").setup({
  flavour = "mocha",
  color_overrides = {
    mocha = {
      base = "#181825",
      mantle = "#11111b",
      crust = "#0b0b12",
    },
  },
  no_italic = true,
  custom_highlights = function(colors)
    local tint = function(color, amount)
      return require("catppuccin.utils.colors").blend(color, colors.base, amount)
    end
    return {
      Folded = { bg = colors.surface0, fg = colors.overlay0 },
      FzfLuaBorder = { fg = colors.surface2, bg = colors.base },
      MsgArea = { fg = colors.text, bg = colors.crust },
      -- Mode badges: Normal is muted, so that only the other modes stand out; those show
      -- their color on a faint tint of it, about as dark as the Normal badge.
      StatusLineNormal = { fg = colors.overlay1, bg = colors.surface0 },
      StatusLineInsert = { fg = colors.green, bg = tint(colors.green, 0.22) },
      StatusLineVisual = { fg = colors.mauve, bg = tint(colors.mauve, 0.22) },
      StatusLineReplace = { fg = colors.red, bg = tint(colors.red, 0.22) },
      StatusLineCommand = { fg = colors.peach, bg = tint(colors.peach, 0.22) },
      StatusLineTerminal = { fg = colors.teal, bg = tint(colors.teal, 0.22) },
      -- A hue no mode badge or diff sign uses, dimmed to keep the file name primary.
      StatusLineBranch = { fg = tint(colors.lavender, 0.75) },
      StatusLineRecording = { fg = colors.red },
      -- Softer diff backgrounds keep syntax colors readable; DiffText marks the changed words.
      -- Yellow blended into the bluish base turns brown and close to red, so the change
      -- colors are picked directly with an OKLCH hue of about 92-95.
      DiffAdd = { bg = tint(colors.green, 0.14) },
      DiffChange = { bg = "#322e1c" },
      DiffText = { bg = "#473c1c" },
      DiffDelete = { bg = tint(colors.red, 0.14) },
      DiffviewDiffAddAsDelete = { bg = tint(colors.red, 0.14) },
      DiffviewFiller = { fg = colors.surface1 },
      GitSignsAdd = { fg = tint(colors.green, 0.70) },
      GitSignsChange = { fg = "#b79c46" },
      GitSignsDelete = { fg = tint(colors.red, 0.70) },
      GitSignsStagedAdd = { fg = tint(colors.green, 0.40) },
      GitSignsStagedChange = { fg = "#726231" },
      GitSignsStagedDelete = { fg = tint(colors.red, 0.40) },
      GitSignsStagedChangedelete = { link = "GitSignsStagedChange" },
      GitSignsStagedTopdelete = { link = "GitSignsStagedDelete" },
      -- Diagnostic icons, in the gutter and the statusline, dimmed like the git signs.
      DiagnosticSignError = { fg = tint(colors.red, 0.70) },
      DiagnosticSignWarn = { fg = "#b79c46" },
      DiagnosticSignInfo = { fg = tint(colors.sky, 0.70) },
      DiagnosticSignHint = { fg = tint(colors.teal, 0.70) },
      YankHighlight = { bg = colors.surface2 },
      BlinkIndent = { fg = colors.surface0 },
      BlinkIndentScope = { fg = colors.surface1 },
      ["@markup.raw"] = { fg = colors.lavender },
      ["@markup.raw.block"] = { fg = colors.lavender },
    }
  end,
  integrations = {
    treesitter = true,
    diffview = true,
    gitsigns = true,
    neotree = true,
    mini = { enabled = true },
    native_lsp = { enabled = true },
  },
})
vim.cmd.colorscheme("catppuccin-nvim")

-- Buffer removal preserving window layout
require("mini.bufremove").setup()

-- Buffer/tab line
local function is_bufferline_buf(bufnr)
  return vim.bo[bufnr].buflisted and vim.bo[bufnr].buftype == ""
end
require("bufferline").setup({
  options = {
    -- Visibility is managed below so that extra tab pages (e.g. Diffview) also show it.
    auto_toggle_bufferline = false,
    close_command = "lua MiniBufremove.wipeout(%d, false)",
    right_mouse_command = "lua MiniBufremove.wipeout(%d, false)",
    middle_mouse_command = "lua MiniBufremove.wipeout(%d, false)",
    custom_filter = is_bufferline_buf,
    offsets = {
      { filetype = "neo-tree", text = "File Explorer", highlight = "Directory", separator = true },
      { filetype = "DiffviewFiles", text = "Diffview", highlight = "Directory", separator = true },
    },
  },
})

-- Read-only views (the ones q closes below): they pop up over the edited files rather than
-- being part of the layout, so on their own they should not bring the bufferline on screen.
local popup_filetypes = { qf = true, help = true, man = true, checkhealth = true }

-- Windows that are part of the layout: neither floats (pickers, hover popups), which
-- nvim_list_wins() includes, nor popup views. A terminal split is layout, quickfix is not.
local function has_layout_windows()
  local count = 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      local buf = vim.api.nvim_win_get_buf(win)
      if not popup_filetypes[vim.bo[buf].filetype] then
        count = count + 1
        if count > 1 then
          return true
        end
      end
    end
  end
  return false
end

-- Show the bufferline once the session is more than one file in one window: several buffers,
-- tab pages, or a layout of several windows (a side panel is just one of those).
local function update_showtabline()
  local bufs = vim.tbl_filter(is_bufferline_buf, vim.api.nvim_list_bufs())
  local multiple = #bufs > 1 or #vim.api.nvim_list_tabpages() > 1 or has_layout_windows()
  vim.o.showtabline = multiple and 2 or 0
end
vim.api.nvim_create_autocmd({
  "BufAdd",
  "BufDelete",
  "BufWinEnter",
  "FileType",
  "TabNew",
  "TabClosed",
  "WinNew",
  "WinClosed",
  "VimEnter",
}, {
  group = vim.api.nvim_create_augroup("BufferlineVisibility", { clear = true }),
  -- Deferred so buflisted/buftype and the buffer and tab lists have settled.
  callback = function() vim.schedule(update_showtabline) end,
})
update_showtabline()

-- File tree explorer
require("neo-tree").setup({
  sources = { "filesystem", "buffers", "git_status" },
  open_files_do_not_replace_types = { "qf" },
  enable_diagnostics = false,
  filesystem = {
    hijack_netrw_behavior = "open_current",
    bind_to_cwd = false,
    follow_current_file = { enabled = true },
    use_libuv_file_watcher = true,
    -- "-" goes up a directory like upstream Neovim's built-in directory browser:
    -- unlike <bs> (navigate_up), it selects the directory it came from rather than
    -- keeping it expanded around the node under the cursor.
    window = {
      mappings = {
        ["-"] = "navigate_parent",
      },
    },
    commands = {
      ---@param state neotree.sources.filesystem.StateWithTree
      navigate_parent = function(state)
        local parent = vim.fs.dirname(state.path)
        if parent == state.path then
          return
        end
        local fs = require("neo-tree.sources.filesystem")
        if state.search_pattern then
          fs.reset_search(state, false)
        end
        fs._navigate_internal(state, parent, state.path, nil, false)
      end,
    },
    filtered_items = {
      visible = false,
      hide_dotfiles = false,
      hide_gitignored = true,
    },
  },
  default_component_configs = {
    symlink_target = {
      enabled = true,
    },
    git_status = {
      symbols = {
        staged = "",
        unstaged = "",
      },
    },
  },
})

-- Fuzzy finder
-- Profile "default" is { "border-fused", "hide" }; "hide" keeps the fzf
-- process alive (parked) after closing a picker. Use "border-fused" alone
-- (same UI, no keep-alive) so fzf only runs while a picker is open.
local fzf_actions = require("fzf-lua.actions")
require("fzf-lua").setup({
  "border-fused",
  winopts = { height = 0.85, width = 0.80 },
  fzf_opts = {
    ["--tabstop"] = "4",
  },
  files = {
    cwd_prompt = false,
  },
  -- The "files" picker searches hidden files by default, "grep" does not, which
  -- hides whole trees such as ~/.config. Setting "hidden" (rather than passing
  -- --hidden in rg_opts) keeps the toggle and its header label in sync.
  grep = {
    multiline = 1,
    hidden = true,
    rg_opts = "--column --line-number --no-heading --color=always "
      .. '--smart-case --max-columns=4096 --trim -g "!.git" -g "!.jj" -e',
  },
  lsp = { multiline = 1, trim_entry = true },
  -- tmux binds Alt+hjkl to pane switching without a prefix, so fzf never sees
  -- <A-h>; move "toggle hidden files" to <A-.> ("dot files"). The leading true
  -- inherits the remaining default file actions instead of replacing them.
  actions = {
    files = {
      true,
      ["alt-h"] = false,
      ["alt-."] = { fn = fzf_actions.toggle_hidden, reuse = true, header = false },
    },
  },
})

-- Treesitter (native TS highlighting)
-- Parsers and queries are built by treesitter.json/treesitter.py in the dotfiles
-- repository, not installed from here. nvim-treesitter stays on the runtimepath only
-- for its grammar table, query files, and filetype aliases.
do
  local ts_hl_group = vim.api.nvim_create_augroup("nvim-treesitter-highlight", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = ts_hl_group,
    callback = function(args)
      pcall(vim.treesitter.start, args.buf)
    end,
  })
end

-- Indent guides + active scope
require("blink.indent").setup({
  blocked = {
    buftypes = { include_defaults = true },
    filetypes = {
      include_defaults = true,
      unpack(indent_exclude_filetypes),
    },
  },
  static = {
    enabled = true,
    char = "\xe2\x94\x82",
    highlights = { "BlinkIndent" },
  },
  scope = {
    enabled = true,
    char = "\xe2\x94\x82",
    highlights = { "BlinkIndentScope" },
  },
})

-- Textobjects for arguments, function calls, quotes, brackets, and more.
-- The treesitter-backed ones read queries/<lang>/textobjects.scm, supplied by
-- nvim-treesitter-textobjects. That plugin stays on the runtimepath for its queries alone;
-- its own select/swap/move modules are never set up, so it adds no mappings of its own.
do
  local ai = require("mini.ai")
  local ts = ai.gen_spec.treesitter

  ai.setup({
    n_lines = 500,
    custom_textobjects = {
      -- Definitions, not calls: `dif` clears a function body, `vac` selects a whole class.
      f = ts({ a = "@function.outer", i = "@function.inner" }),
      c = ts({ a = "@class.outer", i = "@class.inner" }),
      -- Any enclosing block: plain block, conditional, or loop, whichever matches best.
      o = ts({
        a = { "@block.outer", "@conditional.outer", "@loop.outer" },
        i = { "@block.inner", "@conditional.inner", "@loop.inner" },
      }),
      -- Usages, i.e. what builtin `f` meant before it was rebound above.
      u = ai.gen_spec.function_call(),
      U = ai.gen_spec.function_call({ name_pattern = "[%w_]" }),
      d = { "%f[%d]%d+" },
    },
  })
end

-- Git diff viewer
local diffview_actions = require("diffview.actions")

-- Map a line in `old` to the matching line in `new`. A line inside a changed hunk keeps its
-- offset within the hunk, clamped to the replacement lines.
local function map_line_through_diff(old, new, row)
  local hunks = vim.text.diff(
    table.concat(old, "\n") .. "\n",
    table.concat(new, "\n") .. "\n",
    { result_type = "indices" }
  )
  ---@cast hunks integer[][]
  local target = row
  for _, hunk in ipairs(hunks) do
    local old_start, old_count, new_start, new_count = unpack(hunk)
    if row < old_start or (old_count == 0 and row == old_start) then
      break
    end
    if row < old_start + old_count then
      target = new_start + math.min(row - old_start, math.max(new_count - 1, 0))
      break
    end
    target = target + new_count - old_count
  end
  return math.max(1, math.min(target, #new))
end

-- Capture the right-hand diff window's lines and cursor, if gf will open the file it shows.
local function diffview_goto_anchor()
  local view = require("diffview.lib").get_current_view() --[[@as DiffView|FileHistoryView?]]
  if not view or not view.cur_layout or view:infer_cur_file() ~= view.cur_entry then
    return nil
  end
  local main = view.cur_layout:get_main_win()
  local file = main:is_valid() and main.file
  if not file or not file.bufnr or not vim.api.nvim_buf_is_loaded(file.bufnr) then
    return nil
  end
  return {
    path = vim.uv.fs_realpath(file.absolute_path),
    lines = vim.api.nvim_buf_get_lines(file.bufnr, 0, -1, false),
    cursor = vim.api.nvim_win_get_cursor(main.id),
  }
end

-- Diffview's gf reuses the cursor row of the right-hand diff window, which may show a commit or
-- the index rather than the working tree. Anchor the row through a diff of the two versions.
local function diffview_goto_file()
  local anchor = diffview_goto_anchor()

  diffview_actions.goto_file_edit()

  if anchor and anchor.path
    and vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0)) == anchor.path then
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local row = map_line_through_diff(anchor.lines, lines, anchor.cursor[1])
    vim.api.nvim_win_set_cursor(0, { row, anchor.cursor[2] })
  end
end

require("diffview").setup({
  enhanced_diff_hl = true,
  show_help_hints = false,
  compact_panel_headers = true,
  -- Open every file at its first change rather than on the line followed from the last one.
  view = { cursor_carry = false },
  file_history_panel = {
    win_config = { position = "bottom", height = 12 },
    log_options = {
      git = {
        single_file = { max_count = 64 },
        multi_file = { max_count = 64 },
      },
    },
  },
  file_panel = {
    win_config = { position = "bottom", height = 12 },
  },
  hooks = {
    diff_buf_win_enter = function(_, winid)
      vim.wo[winid].cursorlineopt = "number"
      vim.wo[winid].fillchars = "diff:\xc2\xb7,fold: "
      -- Filler lines use DiffDelete; diffview's dim group also colors inline deleted text.
      vim.wo[winid].winhighlight = vim.wo[winid].winhighlight
        :gsub("DiffDelete:DiffviewDiffDeleteDim", "DiffDelete:DiffviewFiller")
    end,
  },
  keymaps = {
    view = {
      { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
      { "n", "za", "za", { desc = "Toggle fold" } },
      { "n", "zi", "zi", { desc = "Toggle foldenable" } },
      { "n", "<leader>e", diffview_actions.toggle_files, { desc = "Toggle file panel" } },
      { "n", "gf", diffview_goto_file, { desc = "Open the file at the matching line" } },
    },
    file_panel = {
      { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
      { "n", "<leader>e", diffview_actions.toggle_files, { desc = "Toggle file panel" } },
      { "n", "gf", diffview_goto_file, { desc = "Open the file at the matching line" } },
    },
    file_history_panel = {
      { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
      { "n", "<leader>e", diffview_actions.toggle_files, { desc = "Toggle file panel" } },
      { "n", "gf", diffview_goto_file, { desc = "Open the file at the matching line" } },
    },
  },
})

vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("nvim-diffview-buffer", { clear = true }),
  callback = function(event)
    local name = vim.api.nvim_buf_get_name(event.buf)
    if not name:find("^diffview://") then
      return
    end

    local is_commit_log = name:find("/commit_log$") ~= nil

    vim.bo[event.buf].modifiable = false
    vim.keymap.set("n", "q", is_commit_log and "<cmd>close<cr>" or "<cmd>DiffviewClose<cr>", {
      buf = event.buf,
      desc = is_commit_log and "Close commit details" or "Close diffview",
    })
    vim.keymap.set("n", "]h", "]c", { buf = event.buf, remap = true, desc = "Next hunk" })
    vim.keymap.set("n", "[h", "[c", { buf = event.buf, remap = true, desc = "Previous hunk" })
  end,
})

local function close_existing_diffviews()
  local ok, lib = pcall(require, "diffview.lib")
  if not ok then
    return
  end

  local views = {}
  for _, view in ipairs(lib.views) do
    table.insert(views, view)
  end

  for _, view in ipairs(views) do
    view:close()
    lib.dispose_view(view)
  end
end

local function open_unique_diffview(command)
  close_existing_diffviews()
  local layout = vim.o.columns < 120 and "diff1_inline" or "diff2_horizontal"
  local view_config = require("diffview.config").get_config().view
  view_config.default.layout = layout
  view_config.file_history.layout = layout
  vim.cmd(command)
end

local function git_has_changes()
  local file = vim.api.nvim_buf_get_name(0)
  local cwd = file ~= "" and vim.fs.dirname(file) or vim.uv.cwd()
  local result = vim.system({
    "git",
    "-C",
    cwd,
    "status",
    "--porcelain=v1",
    "--untracked-files=normal",
  }, { text = true }):wait()

  return result.code == 0 and result.stdout ~= ""
end

-- Git gutter signs
require("gitsigns").setup({
  on_attach = function(bufnr)
    local gs = require("gitsigns")
    local map = function(mode, l, r, desc)
      vim.keymap.set(mode, l, r, { buf = bufnr, desc = desc })
    end
    map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
    map("n", "[h", function() gs.nav_hunk("prev") end, "Previous hunk")
    map("n", "<leader>ghs", gs.stage_hunk, "Stage hunk")
    map("n", "<leader>ghr", gs.reset_hunk, "Reset hunk")
    map("n", "<leader>ghp", gs.preview_hunk, "Preview hunk")
    map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Blame line")
  end,
})

-- Autocompletion
require("blink.cmp").setup({
  keymap = {
    preset = "default",
    ["<CR>"] = { "accept", "fallback" },
    ["<Tab>"] = { "snippet_forward", "accept", "fallback" },
    ["<Esc>"] = {
      function(cmp)
        cmp.cancel()
        return false
      end,
      "fallback",
    },
  },
  appearance = { nerd_font_variant = "mono" },
  completion = {
    accept = {
      auto_brackets = { enabled = true },
    },
    menu = {
      auto_show = function()
        return vim.bo.filetype ~= "markdown"
          and #vim.lsp.get_clients({ bufnr = 0 }) > 0
          and not in_comment_or_string()
      end,
    },
    documentation = {
      auto_show = true,
      auto_show_delay_ms = 200,
    },
  },
  sources = { default = { "lsp", "path", "snippets", "buffer" } },
})

-- LSP servers come from the system, never from Neovim. nvim-lspconfig stays on
-- the runtimepath only for its lsp/*.lua definitions, which vim.lsp.config()
-- merges by name. An uninstalled server fails cmd validation and is skipped
-- silently, so one list works on every machine.

-- TypeScript 7 is a native binary with a built-in --lsp mode and no tsserver.js
-- for typescript-language-server to drive; 6 and older have no --lsp. Homebrew and
-- Arch both link tsc into the package's bin/, so the version is readable from the
-- package.json beside it, without paying a node startup for --version.
local function typescript_server()
  local tsc = vim.fn.exepath("tsc")
  if tsc == "" then
    return "ts_ls"
  end
  local prefix = vim.fs.dirname(vim.fs.dirname(vim.fn.resolve(tsc)))
  local read_ok, lines = pcall(vim.fn.readfile, vim.fs.joinpath(prefix, "package.json"))
  if not read_ok then
    return "ts_ls"
  end
  local decode_ok, pkg = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decode_ok or type(pkg) ~= "table" or type(pkg.version) ~= "string" then
    return "ts_ls"
  end
  local version = vim.version.parse(pkg.version)
  return version and version.major >= 7 and "tsc" or "ts_ls"
end

do
  vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })

  -- Resolve vim.* and plugin modules; upstream lua_ls sets no workspace library. The config
  -- directory is left out: its init.lua links to the dotfiles copy being edited, and loading
  -- both would report every global in it as a duplicate.
  local config_dir = vim.fn.stdpath("config")
  vim.lsp.config("lua_ls", {
    settings = {
      Lua = {
        runtime = { version = "LuaJIT" },
        workspace = {
          library = vim.tbl_filter(function(path)
            return path ~= config_dir
          end, vim.api.nvim_get_runtime_file("", true)),
          checkThirdParty = false,
        },
      },
    },
  })

  vim.lsp.enable({
    "clangd",
    "lua_ls",
    "pyright",
    "rust_analyzer",
    typescript_server(),
  })
end

-- File location for sharing, relative to the git work tree so it means the same
-- in another checkout, or to the working directory outside one.
local function copy_reference(with_lines, line1, line2)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return
  end

  local ref = vim.fn.fnamemodify(file, ":.")
  local root = vim.system({
    "git",
    "-C",
    vim.fs.dirname(file),
    "rev-parse",
    "--show-toplevel",
  }, { text = true }):wait()
  if root.code == 0 then
    local prefix = vim.trim(root.stdout) .. "/"
    if vim.startswith(file, prefix) then
      ref = file:sub(#prefix + 1)
    end
  end

  if with_lines then
    ref = ref .. ":" .. line1 .. (line1 == line2 and "" or "-" .. line2)
  end

  vim.fn.setreg("+", ref)
  vim.api.nvim_echo({ { ref } }, false, {})
end

vim.api.nvim_create_user_command("CopyReference", function(cmd)
  copy_reference(cmd.args ~= "file", cmd.line1, cmd.line2)
end, {
  range = true,
  nargs = "?",
  complete = function()
    return { "file", "line" }
  end,
  desc = "Copy the current file reference, with line numbers unless given \"file\"",
})

--------------------------------------------------------------------------------
-- Keybindings
--------------------------------------------------------------------------------
local map = vim.keymap.set

-- General
map({ "n", "i" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })
-- Clearing the highlight does not redraw the statusline search count on its own.
map("n", "<Esc>", "<cmd>nohlsearch<bar>redrawstatus<cr>", { desc = "Clear search highlight" })
map("n", "<leader>q", "<cmd>qa<cr>", { desc = "Quit all" })
map("n", "<leader>us", "<cmd>setlocal spell! spell?<cr>", { desc = "Toggle spell check" })
map("n", "<leader>uw", "<cmd>setlocal wrap! wrap?<cr>", { desc = "Toggle word wrap" })
-- A plain "<gv" flickers the cursorline: Nvim redraws between the keys of a
-- mapping, in the Normal mode between < and gv. One :normal! runs both without.
map("x", "<", function()
  vim.cmd("normal! " .. vim.v.count1 .. "<gv")
end, { desc = "Indent left (keep selection)" })
map("x", ">", function()
  vim.cmd("normal! " .. vim.v.count1 .. ">gv")
end, { desc = "Indent right (keep selection)" })

-- A stray q must not start recording, and nothing else may start with q: a
-- mapping like q: would make every buffer-local close below wait out
-- 'timeoutlen', so the cmdline window stays on 'cedit' (CTRL-F). Recording goes
-- to <leader>Q, since Nvim 0.13 gives Q and gQ to multicursor.
map("n", "q", "<Nop>", { desc = "Unused (q closes windows)" })
map("n", "<leader>Q", "q", { desc = "Record macro into register" })

-- cutlass takes m for cut, so marks move here. Nothing else may start with gm,
-- or every mark would wait out 'timeoutlen'.
map("n", "gm", "m", { desc = "Set mark" })

-- Diagnostics / quickfix
map("n", "<leader>xd", vim.diagnostic.setqflist, { desc = "Diagnostics to quickfix" })
map("n", "<leader>xq", function()
  local wins = vim.fn.getwininfo()
  for _, win in ipairs(wins) do
    if win.quickfix == 1 and win.loclist == 0 then
      vim.cmd("cclose")
      return
    end
  end
  vim.cmd("botright copen")
end, { desc = "Toggle quickfix list" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Window management
map("n", "<leader>-", "<cmd>split<cr>", { desc = "Split below" })
-- `\` is the unshifted form of `|`, kept as a convenience alias.
map("n", "<leader>|", "<cmd>vsplit<cr>", { desc = "Split right" })
map("n", "<leader>\\", "<cmd>vsplit<cr>", { desc = "Split right" })
map("n", "<leader>wd", "<C-w>c", { desc = "Delete window" })

-- Window resize
local function resize_win(delta, vertical)
  local amount = delta * vim.v.count1
  local cmd = vertical and "vertical resize " or "resize "
  local signed = amount > 0 and ("+" .. amount) or tostring(amount)
  vim.cmd(cmd .. signed)
end
map("n", "<C-Up>",    function() resize_win( 2, false) end, { desc = "Increase window height" })
map("n", "<C-Down>",  function() resize_win(-2, false) end, { desc = "Decrease window height" })
map("n", "<C-Left>",  function() resize_win(-2,  true) end, { desc = "Decrease window width"  })
map("n", "<C-Right>", function() resize_win( 2,  true) end, { desc = "Increase window width"  })

-- Terminals
map("t", "<C-\\>", [[<C-\><C-n>]], { desc = "Terminal: exit to normal mode" })

-- Buffer navigation
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Switch to other buffer" })
map("n", "<leader>bd", function()
  require("mini.bufremove").wipeout(0, false)
end, { desc = "Close buffer (keep layout)" })
map("n", "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", { desc = "Close other buffers" })
map("n", "<leader>bl", "<cmd>BufferLineCloseLeft<cr>", { desc = "Close buffers to the left" })
map("n", "<leader>br", "<cmd>BufferLineCloseRight<cr>", { desc = "Close buffers to the right" })

-- Real Vim tabs (tabpages)
map("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", { desc = "New tabpage" })
map("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close tabpage" })
map("n", "<leader><tab>o", "<cmd>tabonly<cr>", { desc = "Close other tabpages" })
map("n", "<leader><tab>[", "<cmd>tabprevious<cr>", { desc = "Previous tabpage" })
map("n", "<leader><tab>]", "<cmd>tabnext<cr>", { desc = "Next tabpage" })
map("n", "<leader><tab>f", "<cmd>tabfirst<cr>", { desc = "First tabpage" })
map("n", "<leader><tab>l", "<cmd>tablast<cr>", { desc = "Last tabpage" })
map("n", "[t", "<cmd>tabprevious<cr>", { desc = "Previous tabpage" })
map("n", "]t", "<cmd>tabnext<cr>", { desc = "Next tabpage" })

-- File explorer
map("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "Toggle file explorer" })
map("n", "<leader>o", function()
  if vim.bo.filetype == "neo-tree" then
    vim.cmd("wincmd p")
    return
  end
  vim.cmd("Neotree focus")
end, { desc = "Toggle file explorer focus" })
-- Oil-style browsing: "-" opens the current file's parent directory in the current
-- window with the file selected. The per-window state is separate from the sidebar's.
map("n", "-", function()
  local file = vim.api.nvim_buf_get_name(0)
  local args = { source = "filesystem", position = "current" }
  if vim.bo.buftype == "" and file ~= "" and vim.uv.fs_stat(file) then
    args.dir = vim.fs.dirname(file)
    args.reveal_file = file
  else
    args.dir = vim.uv.cwd()
  end
  require("neo-tree.command").execute(args)
end, { desc = "Open parent directory" })
map("n", "<leader>ge", function()
  require("neo-tree.command").execute({ source = "git_status", toggle = true })
end, { desc = "Git explorer" })
map("n", "<leader>be", function()
  require("neo-tree.command").execute({ source = "buffers", toggle = true })
end, { desc = "Buffer explorer" })

-- Fuzzy finder (fzf-lua)
map("n", "<leader><space>", "<cmd>FzfLua files<cr>", { desc = "Find files" })
map("n", "<leader>ff", "<cmd>FzfLua files<cr>", { desc = "Find files" })
map("n", "<leader>/", "<cmd>FzfLua live_grep<cr>", { desc = "Live grep" })
map("n", "<leader>sg", "<cmd>FzfLua live_grep<cr>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>FzfLua buffers<cr>", { desc = "Buffers" })
map("n", "<leader>fr", "<cmd>FzfLua oldfiles<cr>", { desc = "Recent files" })
map("n", "<leader>sh", "<cmd>FzfLua helptags<cr>", { desc = "Help pages" })
map("n", "<leader>sw", "<cmd>FzfLua grep_cword<cr>", { desc = "Grep word under cursor" })
map("n", "<leader>sd", "<cmd>FzfLua diagnostics_document<cr>", { desc = "Diagnostics" })
map("n", "<leader>ss", "<cmd>FzfLua lsp_document_symbols<cr>", { desc = "LSP document symbols" })
map("n", "<leader>sS", "<cmd>FzfLua lsp_live_workspace_symbols<cr>", {
  desc = "LSP workspace symbols (live)",
})

-- Git tools
map("n", "<leader>gd", function()
  if git_has_changes() then
    open_unique_diffview("DiffviewOpen")
  else
    open_unique_diffview("DiffviewFileHistory")
  end
end, { desc = "Diff view or repo history" })
map("n", "<leader>gf", function()
  open_unique_diffview("DiffviewFileHistory %")
end, { desc = "File history (current)" })
map("n", "<leader>gg", function()
  open_unique_diffview("DiffviewFileHistory")
end, { desc = "Git log (repo history)" })

-- Copy references
map({ "n", "x" }, "yr", ":CopyReference file<cr>", { silent = true, desc = "Copy file path" })
map({ "n", "x" }, "yrr", ":CopyReference<cr>", { silent = true, desc = "Copy file:line reference" })

-- Drop the built-in gr* LSP mappings so `gr` below fires without waiting out
-- 'timeoutlen' for a longer sequence.
for _, lhs in ipairs({ "gra", "gri", "grn", "grr", "grt", "grx" }) do
  pcall(vim.keymap.del, "n", lhs)
end
pcall(vim.keymap.del, "x", "gra")

-- LSP, mapped unconditionally rather than on LspAttach: a server can take
-- seconds to start, and until then these keys would fall through to unrelated
-- defaults, gd to a local declaration jump, K to 'keywordprg'. `filter` says
-- which client must be attached: name for a server-specific command, method
-- for a capability.
local function lsp_action(fn, filter)
  return function()
    local buf = vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients(vim.tbl_extend("keep", { bufnr = buf }, filter or {}))
    if not next(clients) then
      local what = filter and filter.name and (filter.name .. " is not attached to this buffer")
        or filter and filter.method and ("No LSP client here supports " .. filter.method)
        or "No LSP client attached to this buffer"
      vim.notify(what, vim.log.levels.WARN)
      return
    end
    fn()
  end
end

map("n", "gd", lsp_action(vim.lsp.buf.definition), { desc = "Go to definition" })
map("n", "gD", lsp_action(vim.lsp.buf.declaration), { desc = "Go to declaration" })
map("n", "gI", lsp_action(vim.lsp.buf.implementation), { desc = "Go to implementation" })
map("n", "gy", lsp_action(vim.lsp.buf.type_definition), { desc = "Go to type definition" })
map("n", "gr", lsp_action(function()
  vim.cmd("FzfLua lsp_references")
end), { desc = "References" })
map("n", "K", lsp_action(vim.lsp.buf.hover), { desc = "Hover documentation" })
map("n", "<leader>cr", lsp_action(vim.lsp.buf.rename), { desc = "Rename symbol" })
map({ "n", "x" }, "<leader>ca", lsp_action(vim.lsp.buf.code_action), { desc = "Code action" })
-- A clangd extension; the command exists only while clangd is attached.
map("n", "<leader>ch", lsp_action(function()
  vim.cmd("LspClangdSwitchSourceHeader")
end, { name = "clangd" }), { desc = "Switch Source/Header (C/C++)" })
map("n", "<leader>uh", lsp_action(function()
  local buf = vim.api.nvim_get_current_buf()
  local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
  vim.lsp.inlay_hint.enable(not enabled, { bufnr = buf })
end, { method = "textDocument/inlayHint" }), { desc = "Toggle inlay hints" })

-- Unguarded: diagnostics also come from sources other than LSP.
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "[e", function()
  vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR })
end, { desc = "Previous error" })
map("n", "]e", function()
  vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR })
end, { desc = "Next error" })
map("n", "[w", function()
  vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.WARN })
end, { desc = "Previous warning" })
map("n", "]w", function()
  vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.WARN })
end, { desc = "Next warning" })

--------------------------------------------------------------------------------
-- Autocommands
--------------------------------------------------------------------------------

-- Never hard-wrap: ftplugins (gitcommit, markdown, ...) and .editorconfig
-- max_line_length both set textwidth per buffer, so undo it after they run.
vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  group = vim.api.nvim_create_augroup("nvim-no-textwidth", { clear = true }),
  callback = function()
    vim.bo.textwidth = 0
  end,
})

-- Drop scroll padding in side panels, where it makes mouse clicks near the top
-- or bottom scroll the list instead of selecting the entry.
vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  group = vim.api.nvim_create_augroup("nvim-panel-scrolloff", { clear = true }),
  callback = function()
    local panel_filetypes = {
      ["neo-tree"] = true,
      ["DiffviewFiles"] = true,
      ["DiffviewFileHistory"] = true,
    }
    if panel_filetypes[vim.bo.filetype] then
      vim.wo.scrolloff = 0
      vim.wo.sidescrolloff = 0
    end
  end,
})

-- C/C++ indentation tweaks for Vim's built-in cindent engine.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("nvim-cpp-indent", { clear = true }),
  pattern = { "c", "cpp" },
  callback = function()
    -- l1: align braces in "case X: {" blocks with the case label.
    -- j1: improves indentation for inline lambda/function-style constructs.
    -- (s: indent unclosed parentheses one shiftwidth, not the default two.
    -- u0: keep nested unclosed parentheses at that same continuation indent.
    -- ks: indent unclosed if/for/while conditions one shiftwidth, not two.
    -- m1: align closing parentheses with the matching opening line.
    vim.bo.cinoptions = "l1,j1,(s,u0,ks,m1"
    -- Reindent on block delimiters/preprocessor/newline/else, but not on ":".
    -- Omitting ":" avoids extra reindent churn while typing labels/case lines.
    vim.bo.cinkeys = "0{,0},0),0],0#,!^F,o,O,e"
  end,
})

-- Close read-only views with q. bdelete covers the last window, where close
-- raises E444.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("nvim-close-view", { clear = true }),
  pattern = { "qf", "help", "man", "checkhealth" },
  callback = function(event)
    vim.keymap.set("n", "q", function()
      vim.cmd(vim.fn.winnr("$") > 1 and "close" or "bdelete")
    end, { buf = event.buf, silent = true, desc = "Close window" })
  end,
})

-- Only :edit reuses the initial empty buffer; switching to an added buffer leaves it behind.
local function is_unused_buffer(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.bo[buf].buflisted
    and vim.bo[buf].buftype == ""
    and not vim.bo[buf].modified
    and vim.api.nvim_buf_get_name(buf) == ""
    and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
    and vim.fn.undotree(buf).seq_last == 0 -- 'modified' misses a draft undone to empty
end
vim.api.nvim_create_autocmd("BufHidden", {
  group = vim.api.nvim_create_augroup("nvim-wipe-unused-buffer", { clear = true }),
  callback = function(event)
    if not is_unused_buffer(event.buf) then
      return
    end
    -- A buffer can't be wiped while it is being hidden.
    vim.schedule(function()
      if is_unused_buffer(event.buf) and #vim.fn.win_findbuf(event.buf) == 0 then
        vim.api.nvim_buf_delete(event.buf, {})
      end
    end)
  end,
})

-- Auto-reload buffers when external changes are detected.
-- autoread alone only reloads on :commands; checktime is needed to actually poll.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("nvim-auto-reload", { clear = true }),
  callback = function()
    if vim.fn.mode() ~= "c" then
      vim.cmd("checktime")
    end
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("nvim-highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank({ higroup = "YankHighlight" })
  end,
})
