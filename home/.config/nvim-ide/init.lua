-- nvim-ide: standalone Neovim IDE config (NVIM_APPNAME=nvim-ide)

--------------------------------------------------------------------------------
-- Bootstrap
--------------------------------------------------------------------------------
vim.loader.enable()

if not vim.pack then
  error("nvim-ide requires Neovim 0.12+ with built-in vim.pack")
end

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
vim.opt.laststatus = 3
vim.opt.fillchars:append({ eob = " " })

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

-- Clipboard
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
local diagnostic_icons = {
  Error = "\xef\x81\x97", -- error circle with X
  Warn  = "\xef\x81\xb1", -- warning triangle
  Hint  = "\xef\x83\xab", -- lightbulb hint
  Info  = "\xef\x81\x9a", -- info circle
}

vim.diagnostic.config({
  virtual_text = {
    prefix = function(diagnostic)
      local icons = { diagnostic_icons.Error, diagnostic_icons.Warn, diagnostic_icons.Info, diagnostic_icons.Hint }
      return icons[diagnostic.severity] or diagnostic_icons.Info
    end,
    spacing = 1,
  },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = diagnostic_icons.Error,
      [vim.diagnostic.severity.WARN]  = diagnostic_icons.Warn,
      [vim.diagnostic.severity.HINT]  = diagnostic_icons.Hint,
      [vim.diagnostic.severity.INFO]  = diagnostic_icons.Info,
    },
  },
})

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local indent_exclude_filetypes = {
  "Trouble",
  "alpha",
  "dashboard",
  "fzf",
  "help",
  "mason",
  "neo-tree",
  "notify",
  "toggleterm",
  "trouble",
  "render-markdown",
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

-- Keep Tree-sitter parsers in sync with plugin updates.
-- This hook is plugin-specific: unlike Mason-managed tools, nvim-treesitter
-- expects a TSUpdate step after install/update to avoid parser/runtime drift.
vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("nvim-ide-pack-hooks", { clear = true }),
  callback = function(event)
    local data = event.data
    if not data or not data.spec or data.spec.name ~= "nvim-treesitter" then
      return
    end
    if data.kind ~= "install" and data.kind ~= "update" then
      return
    end
    if not data.active then
      vim.cmd.packadd("nvim-treesitter")
    end
    vim.schedule(function()
      pcall(vim.cmd, "TSUpdate")
    end)
  end,
})

vim.pack.add({
  { src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/NMAC427/guess-indent.nvim",
  "https://github.com/MunifTanjim/nui.nvim",
  "https://github.com/rcarriga/nvim-notify",
  "https://github.com/nvim-mini/mini.icons",
  "https://github.com/nvim-mini/mini.bufremove",
  "https://github.com/nvim-mini/mini.indentscope",
  "https://github.com/nvim-mini/mini.ai",
  "https://github.com/SmiteshP/nvim-navic",
  "https://github.com/justinhj/battery.nvim",
  "https://github.com/nvim-lualine/lualine.nvim",
  "https://github.com/akinsho/bufferline.nvim",
  "https://github.com/nvim-neo-tree/neo-tree.nvim",
  "https://github.com/akinsho/toggleterm.nvim",
  "https://github.com/stevearc/stickybuf.nvim",
  "https://github.com/stevearc/overseer.nvim",
  "https://github.com/ibhagwan/fzf-lua",
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/saghen/blink.indent",
  "https://github.com/sindrets/diffview.nvim",
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/mason-org/mason.nvim",
  "https://github.com/mason-org/mason-lspconfig.nvim",
  "https://github.com/neovim/nvim-lspconfig",
  { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1.x") },
  "https://github.com/MeanderingProgrammer/render-markdown.nvim",
  "https://github.com/windwp/nvim-autopairs",
  "https://github.com/cajames/copy-reference.nvim",
  "https://github.com/folke/which-key.nvim",
  "https://github.com/folke/noice.nvim",
})

-- In init.lua, vim.pack.add() registers all plugins first; configure mini.icons
-- and install its devicons shim before requiring plugins that consume icons.
-- File icons
require("mini.icons").setup({})
MiniIcons.mock_nvim_web_devicons()

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
  group = vim.api.nvim_create_augroup("nvim-ide-tab-indent-backspace", { clear = true }),
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
  no_italic = true,
  custom_highlights = function(colors)
    return {
      Folded = { bg = colors.surface0, fg = colors.overlay0 },
      DiffChange = { bg = "#3a3529" },
      DiffText = { bg = "#4d4632" },
      YankHighlight = { bg = colors.surface2 },
      BlinkIndent = { fg = colors.surface0 },
      MiniIndentscopeSymbol = { fg = colors.surface1 },
      ["@markup.raw"] = { fg = colors.lavender },
      ["@markup.raw.block"] = { fg = colors.lavender },
      RenderMarkdownCodeInline = { fg = colors.lavender, bg = colors.mantle },
    }
  end,
  integrations = {
    treesitter = true,
    diffview = true,
    gitsigns = true,
    neotree = true,
    mini = { enabled = true, indentscope_color = "surface2" },
    native_lsp = { enabled = true },
    navic = { enabled = true },
    noice = true,
    notify = true,
    which_key = true,
  },
})
vim.cmd.colorscheme("catppuccin-nvim")

-- LSP breadcrumb
require("nvim-navic").setup({
  lsp = { auto_attach = true },
  highlight = true,
  separator = " ",
})

-- Battery status
require("battery").setup({
  update_rate_seconds = 30,
  show_status_when_no_battery = false,
  show_plugged_icon = true,
  show_unplugged_icon = true,
  show_percent = true,
})

-- Status line
require("lualine").setup({
  options = {
    theme = "catppuccin-nvim",
    globalstatus = true,
    component_separators = { left = "", right = "" },
    refresh = {
      refresh_time = 200,
    },
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch" },
    lualine_c = {
      { "filetype", icon_only = true, padding = { left = 1, right = 0 } },
      { "filename", path = 1 },
      {
        function() return require("nvim-navic").get_location() end,
        cond = function() return require("nvim-navic").is_available() end,
      },
    },
    lualine_x = {
      {
        "diagnostics",
        symbols = {
          error = diagnostic_icons.Error .. " ",
          warn  = diagnostic_icons.Warn .. " ",
          hint  = diagnostic_icons.Hint .. " ",
          info  = diagnostic_icons.Info .. " ",
        },
      },
      {
        "diff",
        source = function()
          local s = vim.b.gitsigns_status_dict
          if not s then
            return nil
          end
          return {
            added = s.added or 0,
            modified = s.changed or 0,
            removed = s.removed or 0,
          }
        end,
      },
    },
    lualine_y = { "location" },
    lualine_z = {
      {
        function() return require("battery").get_status_line() end,
        padding = { left = 1, right = 0 },
      },
      function() return "\xef\x90\xba " .. os.date("%R") end,
    },
  },
})

-- Buffer removal preserving window layout
require("mini.bufremove").setup()

-- Buffer/tab line
require("bufferline").setup({
  options = {
    close_command = "lua MiniBufremove.wipeout(%d, false)",
    right_mouse_command = "lua MiniBufremove.wipeout(%d, false)",
    middle_mouse_command = "lua MiniBufremove.wipeout(%d, false)",
    diagnostics = "nvim_lsp",
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
  open_files_do_not_replace_types = { "Trouble", "trouble", "qf" },
  filesystem = {
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
    diagnostics = {
      symbols = {
        hint = diagnostic_icons.Hint,
        info = diagnostic_icons.Info,
        warn = diagnostic_icons.Warn,
        error = diagnostic_icons.Error,
      },
    },
  },
})

-- Integrated terminals
require("toggleterm").setup({
  start_in_insert = true,
  persist_mode = false,
  auto_scroll = false,
})

do
  local Terminal = require("toggleterm.terminal").Terminal

  local bottom_size = function()
    return 20
  end

  local side_size = function()
    return math.max(50, math.floor(vim.o.columns * 0.33))
  end

  local no_appname = "env -u NVIM_APPNAME "
  local shell = os.getenv("SHELL") or "bash"
  local shell_cmd = no_appname .. shell
  local claude_cmd = no_appname .. "claude --dangerously-skip-permissions"
  local codex_cmd = no_appname .. "codex --yolo"
  local hax_cmd = no_appname .. "hax"
  local opencode_cmd = no_appname .. "opencode"

  local terms = {
    general  = Terminal:new({ cmd = shell_cmd,    direction = "horizontal" }),
    side     = Terminal:new({ cmd = shell_cmd,    direction = "vertical"   }),
    claude   = Terminal:new({ cmd = claude_cmd,   direction = "vertical"   }),
    codex    = Terminal:new({ cmd = codex_cmd,    direction = "vertical"   }),
    hax      = Terminal:new({ cmd = hax_cmd,      direction = "vertical"   }),
    opencode = Terminal:new({ cmd = opencode_cmd, direction = "vertical"   }),
  }

  local function close_terms(except_name)
    for name, term in pairs(terms) do
      if name ~= except_name and term:is_open() then
        term:close()
      end
    end
  end

  local function toggle_term(name, size_fn)
    close_terms(name)
    local size = size_fn and size_fn() or nil
    terms[name]:toggle(size)
  end

  local function user_command(name, rhs, desc)
    pcall(vim.api.nvim_del_user_command, name)
    vim.api.nvim_create_user_command(name, rhs, { desc = desc })
  end

  user_command("TermGeneral",  function() toggle_term("general", bottom_size) end, "Toggle bottom terminal")
  user_command("TermSide",     function() toggle_term("side", side_size) end, "Toggle general side terminal")
  user_command("TermClaude",   function() toggle_term("claude", side_size) end, "Toggle Claude Code side terminal")
  user_command("TermCodex",    function() toggle_term("codex", side_size) end, "Toggle Codex side terminal")
  user_command("TermHax",      function() toggle_term("hax", side_size) end, "Toggle hax side terminal")
  user_command("TermOpenCode", function() toggle_term("opencode", side_size) end, "Toggle OpenCode side terminal")
end

-- Keep special windows pinned to compatible buffers (prevents replacing toggleterm windows)
require("stickybuf").setup({})

-- Task runner
require("overseer").setup({})

vim.api.nvim_create_user_command("Make", function(params)
  local cmd, num_subs = vim.o.makeprg:gsub("%$%*", params.args)
  if num_subs == 0 then
    cmd = cmd .. " " .. params.args
  end
  local notify = require("notify")
  local notif = notify("Running: " .. cmd, "info", { timeout = false })
  local task = require("overseer").new_task({
    cmd = vim.fn.expandcmd(cmd),
    components = {
      {
        "on_output_quickfix",
        open = false,
        open_on_match = not params.bang,
        tail = true,
      },
      "on_exit_set_status",
      { "on_complete_dispose", require_view = { "SUCCESS", "FAILURE" } },
    },
  })
  local function last_output()
    local bufnr = task:get_bufnr()
    if bufnr then
      local lines = require("overseer.util").get_last_output_lines(bufnr, 1)
      if #lines > 0 then
        local line = vim.trim(lines[1])
        if #line > 60 then line = line:sub(1, 57) .. "..." end
        return line
      end
    end
  end
  task:subscribe("on_output", function()
    local line = last_output()
    if line then
      notif = notify("Running: " .. cmd .. "\n" .. line, "info", { replace = notif, timeout = false })
    end
  end)
  task:subscribe("on_complete", function(_, status)
    local level = status == "SUCCESS" and "info" or "error"
    local msg = status .. ": " .. cmd
    local line = last_output()
    if line then msg = msg .. "\n" .. line end
    notify(msg, level, { replace = notif, timeout = 1500 })
  end)
  task:start()
end, {
  desc = "Run your makeprg as an Overseer task",
  nargs = "*",
  bang = true,
})

vim.cmd([[cnoreabbrev <expr> make getcmdtype() == ':' && getcmdline() ==# 'make' ? 'Make' : 'make']])

-- Fuzzy finder
require("fzf-lua").setup({
  "default",
  winopts = { height = 0.85, width = 0.80 },
  fzf_opts = {
    ["--tabstop"] = "4",
  },
  files = {
    cwd_prompt = false,
  },
  grep = {
    multiline = 1,
    rg_opts = [[--column --line-number --no-heading --color=always --smart-case --max-columns=4096 --trim -e]],
  },
})

-- Treesitter (parser installation + native TS highlighting)
do
  local ensure_installed = {
    "lua", "vim", "vimdoc", "bash", "json", "yaml", "toml",
    "markdown", "markdown_inline", "python", "javascript", "typescript", "tsx",
    "html", "css", "go", "rust", "c", "cpp",
  }

  local ts = require("nvim-treesitter")
  ts.setup()
  ts.install(ensure_installed)

  local ts_hl_group = vim.api.nvim_create_augroup("nvim-ide-treesitter-highlight", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = ts_hl_group,
    callback = function(args)
      pcall(vim.treesitter.start, args.buf)
    end,
  })
end

-- Indent guides (static only — scope is handled by mini.indentscope)
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
  scope = { enabled = false },
})

-- Active indent scope (debounced to avoid treesitter rehighlight storms on scroll)
do
  local opts = {
    symbol = "\xe2\x94\x82",
    options = { try_as_border = true },
    draw = { delay = 200 },
  }

  local mis = require("mini.indentscope")
  opts.draw.animation = mis.gen_animation.none()
  mis.setup(opts)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = indent_exclude_filetypes,
    callback = function() vim.b.miniindentscope_disable = true end,
  })
end

-- Textobjects for arguments, function calls, quotes, brackets, and more
require("mini.ai").setup({
  n_lines = 500,
})

-- Git diff viewer
require("diffview").setup({
  enhanced_diff_hl = true,
  show_help_hints = false,
  file_panel = {
    win_config = { width = 40 },
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
    },
    file_panel = {
      { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
    },
    file_history_panel = {
      { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
    },
  },
})

vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("nvim-ide-diffview-buffer", { clear = true }),
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
    vim.keymap.set("n", "]h", "]c", { buf = event.buf, desc = "Next hunk" })
    vim.keymap.set("n", "[h", "[c", { buf = event.buf, desc = "Previous hunk" })
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
  vim.cmd(command)
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

-- LSP: mason + mason-lspconfig + lspconfig
require("mason").setup({})
require("mason-lspconfig").setup({
  ensure_installed = { "lua_ls" },
  automatic_enable = true,
})

-- Autocompletion
require("blink.cmp").setup({
  keymap = {
    preset = "default",
    ["<CR>"] = { "accept", "fallback" },
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

do
  local capabilities = require("blink.cmp").get_lsp_capabilities()

  vim.lsp.config("*", { capabilities = capabilities })

  vim.lsp.config("vtsls", {
    root_dir = function(bufnr, on_dir)
      local util = require("lspconfig.util")
      local ts_root = util.root_pattern("tsconfig.json")
      local fallback_root = util.root_pattern("package.json", "jsconfig.json")

      local fname = vim.api.nvim_buf_get_name(bufnr)
      local startpath = vim.fs.dirname(fname)
      local git_dir = startpath and vim.fs.find(".git", { path = startpath, upward = true })[1]
      local git_root = git_dir and vim.fs.dirname(git_dir)
      local root = git_root or ts_root(fname) or fallback_root(fname)
      return root and on_dir(root)
    end,
  })

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
end

-- Markdown rendering (on-demand)
require("render-markdown").setup({
  enabled = false,
  code = { sign = false, width = "block", right_pad = 1 },
  render_modes = true,
  anti_conceal = { enabled = false },
})

-- Auto-close brackets/quotes
require("nvim-autopairs").setup({ check_ts = true })

-- Copy file and line references (useful for sharing exact code locations)
require("copy-reference").setup({
  register = "+",
  use_git_root = true,
})

-- Keybinding discovery popup
require("which-key").setup({
  preset = "helix",
  spec = {
    { "<leader>f", group = "find/file" },
    { "<leader>c", group = "code" },
    { "<leader>g", group = "git" },
    { "<leader>b", group = "buffer" },
    { "<leader><tab>", group = "tabpage" },
    { "<leader>s", group = "search" },
    { "<leader>t", group = "terminal" },
    { "<leader>u", group = "ui/toggle" },
    { "<leader>x", group = "diagnostics/quickfix" },
    { "<leader>w", group = "window", proxy = "<c-w>" },
    { "<leader>q", group = "quit" },
    { "<leader>gh", group = "hunks" },
    { "[", group = "prev" },
    { "]", group = "next" },
    { "g", group = "goto" },
    { "z", group = "fold" },
  },
})

-- Message and cmdline UI with persistent history
require("notify").setup({
  timeout = 1500,
  render = "minimal",
  stages = "static",
  minimum_width = 60,
})
vim.notify = require("notify")

require("noice").setup({
  lsp = {
    progress = { enabled = false },
  },
  messages = {
    view = "mini",
  },
  views = {
    cmdline_popup = {
      position = {
        row = 5,
        col = "50%",
      },
    },
  },
})

--------------------------------------------------------------------------------
-- Keybindings
--------------------------------------------------------------------------------
local map = vim.keymap.set

-- General
map({ "n", "i" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })
map("n", "<leader>sm", "<cmd>Noice history<cr>", { desc = "Message history" })
map("n", "<leader>us", "<cmd>setlocal spell! spell?<cr>", { desc = "Toggle spell check" })
map("n", "<leader>uw", "<cmd>setlocal wrap! wrap?<cr>", { desc = "Toggle word wrap" })

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
map("n", "<leader>|", "<cmd>vsplit<cr>", { desc = "Split right" })
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

-- Integrated terminals
map("t", "<C-\\>", [[<C-\><C-n>]], { desc = "Terminal: exit to normal mode" })
map("n", "<leader>tt", "<cmd>TermGeneral<cr>", { desc = "Terminal: general (bottom)" })
map("n", "<leader>ts", "<cmd>TermSide<cr>", { desc = "Terminal: general (side)" })
map("n", "<leader>tc", "<cmd>TermClaude<cr>", { desc = "Terminal: Claude Code (side)" })
map("n", "<leader>tx", "<cmd>TermCodex<cr>", { desc = "Terminal: Codex (side)" })
map("n", "<leader>th", "<cmd>TermHax<cr>", { desc = "Terminal: hax (side)" })
map("n", "<leader>to", "<cmd>TermOpenCode<cr>", { desc = "Terminal: OpenCode (side)" })

-- Buffer navigation
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "]b", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Switch to other buffer" })
map("n", "<leader>bd", function() require("mini.bufremove").wipeout(0, false) end, { desc = "Close buffer (keep layout)" })
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
map("n", "<leader>sS", "<cmd>FzfLua lsp_live_workspace_symbols<cr>", { desc = "LSP workspace symbols (live)" })

-- Git tools
map("n", "<leader>gd", function()
  open_unique_diffview("DiffviewOpen")
end, { desc = "Diff view (index)" })
map("n", "<leader>gf", function()
  open_unique_diffview("DiffviewFileHistory %")
end, { desc = "File history (current)" })
map("n", "<leader>gF", function()
  open_unique_diffview("DiffviewFileHistory")
end, { desc = "File history (repo)" })

-- UI toggles
map("n", "<leader>um", "<cmd>RenderMarkdown toggle<cr>", { desc = "Toggle markdown render" })

-- Copy references
map({ "n", "v" }, "yr", "<cmd>CopyReference file<cr>", { desc = "Copy file path" })
map({ "n", "v" }, "yrr", "<cmd>CopyReference line<cr>", { desc = "Copy file:line reference" })

-- LSP keybindings (buffer-local, set via LspAttach)
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("nvim-ide-lsp-attach", { clear = true }),
  callback = function(event)
    local buf = event.buf
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    local lmap = function(mode, l, r, desc)
      vim.keymap.set(mode, l, r, { buf = buf, desc = desc })
    end

    lmap("n", "gd", vim.lsp.buf.definition, "Go to definition")
    lmap("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
    lmap("n", "gI", vim.lsp.buf.implementation, "Go to implementation")
    lmap("n", "gy", vim.lsp.buf.type_definition, "Go to type definition")
    lmap("n", "gr", "<cmd>FzfLua lsp_references<cr>", "References")
    lmap("n", "K", vim.lsp.buf.hover, "Hover documentation")
    lmap("n", "<leader>cr", vim.lsp.buf.rename, "Rename symbol")
    lmap("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
    if client and client.name == "clangd" then
      lmap("n", "<leader>ch", "<cmd>LspClangdSwitchSourceHeader<cr>", "Switch Source/Header (C/C++)")
    end
    if client and vim.lsp.inlay_hint and client:supports_method("textDocument/inlayHint", buf) then
      lmap("n", "<leader>uh", function()
        local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
        vim.lsp.inlay_hint.enable(not enabled, { bufnr = buf })
      end, "Toggle inlay hints")
    end
    lmap("n", "<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
    lmap("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, "Previous diagnostic")
    lmap("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, "Next diagnostic")
    lmap("n", "[e", function() vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR }) end, "Previous error")
    lmap("n", "]e", function() vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR }) end, "Next error")
    lmap("n", "[w", function() vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.WARN }) end, "Previous warning")
    lmap("n", "]w", function() vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.WARN }) end, "Next warning")
  end,
})

--------------------------------------------------------------------------------
-- Autocommands
--------------------------------------------------------------------------------

-- C/C++ indentation tweaks for Vim's built-in cindent engine.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("nvim-ide-cpp-indent", { clear = true }),
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

-- Close quickfix / loclist with q
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("nvim-ide-quickfix-close", { clear = true }),
  pattern = "qf",
  callback = function(event)
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buf = event.buf, silent = true })
  end,
})

-- Keep neo-tree git status in sync with gitsigns updates.
local git_ui_refresh = vim.api.nvim_create_augroup("nvim-ide-git-ui-refresh", { clear = true })
local function refresh_git_ui()
  local ok, events = pcall(require, "neo-tree.events")
  if ok then
    events.fire_event(events.GIT_EVENT)
  end
end
vim.api.nvim_create_autocmd("User", {
  group = git_ui_refresh,
  pattern = { "GitSignsUpdate", "GitSignsChanged" },
  callback = refresh_git_ui,
})
vim.api.nvim_create_autocmd("FocusGained", {
  group = git_ui_refresh,
  callback = refresh_git_ui,
})

-- Auto-reload buffers when external changes are detected.
-- autoread alone only reloads on :commands; checktime is needed to actually poll.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("nvim-ide-auto-reload", { clear = true }),
  callback = function()
    if vim.fn.mode() ~= "c" then
      vim.cmd("checktime")
    end
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("nvim-ide-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ higroup = "YankHighlight" })
  end,
})

-- Restore cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("nvim-ide-restore-cursor", { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, "\"")
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Neo-tree's async git status reports ignored files after its fast first pass;
-- warm it here so gitignored items are hidden before the first tree render.
local function warm_neo_tree_git_status(path)
  pcall(function()
    require("neo-tree").ensure_config()
    require("neo-tree.git").status(path, nil, false)
  end)
end

-- Open an IDE-like layout when starting with a directory: tree left + editor right.
local function open_ide_layout()
  local cwd = vim.uv.cwd()
  warm_neo_tree_git_status(cwd)
  require("neo-tree.command").execute({ action = "show", dir = cwd })
  vim.cmd("wincmd p")
end

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("nvim-ide-startup-layout", { clear = true }),
  callback = function(data)
    local argc = vim.fn.argc()

    if argc == 0 then
      open_ide_layout()
      return
    end

    if argc ~= 1 or vim.fn.isdirectory(data.file) ~= 1 then
      return
    end

    vim.cmd.cd(data.file)
    vim.cmd.enew()
    pcall(function()
      vim.cmd("bwipeout " .. data.buf)
    end)

    open_ide_layout()
  end,
})
