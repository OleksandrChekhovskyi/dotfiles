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
vim.opt.laststatus = 1
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
    return {
      Folded = { bg = colors.surface0, fg = colors.overlay0 },
      FzfLuaBorder = { fg = colors.surface2, bg = colors.base },
      MsgArea = { fg = colors.text, bg = colors.crust },
      DiffChange = { bg = "#3a3529" },
      DiffText = { bg = "#4d4632" },
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
require("bufferline").setup({
  options = {
    always_show_bufferline = false,
    close_command = "lua MiniBufremove.wipeout(%d, false)",
    right_mouse_command = "lua MiniBufremove.wipeout(%d, false)",
    middle_mouse_command = "lua MiniBufremove.wipeout(%d, false)",
    custom_filter = function(bufnr)
      return vim.bo[bufnr].buflisted and vim.bo[bufnr].buftype == ""
    end,
    offsets = {
      { filetype = "neo-tree", text = "File Explorer", highlight = "Directory", separator = true },
      { filetype = "DiffviewFiles", text = "Diffview", highlight = "Directory", separator = true },
    },
  },
})

-- File tree explorer
require("neo-tree").setup({
  sources = { "filesystem", "buffers", "git_status" },
  open_files_do_not_replace_types = { "qf" },
  filesystem = {
    hijack_netrw_behavior = "open_current",
    bind_to_cwd = false,
    follow_current_file = { enabled = true },
    use_libuv_file_watcher = true,
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
require("diffview").setup({
  enhanced_diff_hl = true,
  show_help_hints = false,
  file_history_panel = {
    log_options = {
      git = {
        single_file = { max_count = 64 },
        multi_file = { max_count = 64 },
      },
    },
  },
  file_panel = {
    win_config = { position = "bottom", height = 16 },
  },
  hooks = {
    diff_buf_win_enter = function(_, winid)
      vim.wo[winid].cursorlineopt = "number"
      vim.wo[winid].fillchars = "diff:\xc2\xb7,fold: "
    end,
  },
  keymaps = {
    view = {
      { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
      { "n", "za", "za", { desc = "Toggle fold" } },
      { "n", "zi", "zi", { desc = "Toggle foldenable" } },
      { "n", "<leader>e", diffview_actions.toggle_files, { desc = "Toggle file panel" } },
    },
    file_panel = {
      { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
      { "n", "<leader>e", diffview_actions.toggle_files, { desc = "Toggle file panel" } },
    },
    file_history_panel = {
      { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
      { "n", "<leader>e", diffview_actions.toggle_files, { desc = "Toggle file panel" } },
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
    map("n", "]h", gs.next_hunk, "Next hunk")
    map("n", "[h", gs.prev_hunk, "Previous hunk")
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

  -- Resolve vim.* and plugin modules; upstream lua_ls sets no workspace library.
  vim.lsp.config("lua_ls", {
    settings = {
      Lua = {
        workspace = {
          library = vim.api.nvim_get_runtime_file("", true),
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
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })
map("n", "<leader>us", "<cmd>setlocal spell! spell?<cr>", { desc = "Toggle spell check" })
map("n", "<leader>uw", "<cmd>setlocal wrap! wrap?<cr>", { desc = "Toggle word wrap" })

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

-- Move lines
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move lines down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move lines up" })

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
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "]b", "<cmd>bnext<cr>", { desc = "Next buffer" })
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
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Previous diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
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
    vim.highlight.on_yank({ higroup = "YankHighlight" })
  end,
})
