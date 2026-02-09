-- nvim-ide: standalone Neovim IDE config (NVIM_APPNAME=nvim-ide)

--------------------------------------------------------------------------------
-- Bootstrap lazy.nvim
--------------------------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

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
vim.opt.scrolloff = 8
vim.opt.wrap = false
vim.opt.textwidth = 0
vim.opt.laststatus = 3
vim.opt.cmdheight = 0
vim.opt.showcmd = false
vim.opt.messagesopt = "wait:1000,history:500"
vim.opt.shortmess:append("W")
vim.opt.shortmess:append("I")
vim.opt.shortmess:append("c")

-- Splits
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Files
vim.opt.swapfile = false
vim.opt.undofile = true

-- Mouse
vim.opt.mouse = "a"

-- Spell
vim.opt.spell = false

-- Clipboard
vim.opt.clipboard = "unnamedplus"

-- Timing
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300

--------------------------------------------------------------------------------
-- Plugins
--------------------------------------------------------------------------------
local indent_exclude_filetypes = {
  "Trouble",
  "alpha",
  "dashboard",
  "fzf",
  "help",
  "lazy",
  "mason",
  "neo-tree",
  "notify",
  "toggleterm",
  "trouble",
}

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
})

require("lazy").setup({
  -- Color scheme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      no_italic = true,
      integrations = {
        treesitter = true,
        gitsigns = true,
        neotree = true,
        indent_blankline = { enabled = true },
        mini = { enabled = true, indentscope_color = "surface2" },
        native_lsp = { enabled = true },
        navic = { enabled = true },
        which_key = true,
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  -- File icons
  {
    "nvim-mini/mini.icons",
    opts = {},
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },

  -- LSP breadcrumb
  {
    "SmiteshP/nvim-navic",
    opts = {
      lsp = { auto_attach = true },
      highlight = true,
      separator = " ",
    },
  },

  -- Battery status
  {
    "justinhj/battery.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      update_rate_seconds = 30,
      show_status_when_no_battery = false,
      show_plugged_icon = true,
      show_unplugged_icon = true,
      show_percent = true,
    },
  },

  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-mini/mini.icons", "SmiteshP/nvim-navic", "justinhj/battery.nvim" },
    opts = {
      options = {
        theme = "catppuccin",
        globalstatus = true,
        component_separators = { left = "", right = "" },
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
          "diff",
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
    },
  },

  -- Buffer/tab line
  {
    "akinsho/bufferline.nvim",
    dependencies = {
      "nvim-mini/mini.icons",
      "catppuccin/nvim",
      "nvim-mini/mini.bufremove",
    },
    opts = {
      options = {
        close_command = "lua MiniBufremove.wipeout(%d, false)",
        right_mouse_command = "lua MiniBufremove.wipeout(%d, false)",
        middle_mouse_command = "lua MiniBufremove.wipeout(%d, false)",
        diagnostics = "nvim_lsp",
        offsets = {
          { filetype = "neo-tree", text = "File Explorer", highlight = "Directory", separator = true },
        },
      },
    },
  },

  -- File tree explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-mini/mini.icons",
    },
    opts = {
      sources = { "filesystem", "buffers", "git_status" },
      open_files_do_not_replace_types = { "terminal", "Trouble", "trouble", "qf", "edgy" },
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
        diagnostics = {
          symbols = {
            hint = diagnostic_icons.Hint,
            info = diagnostic_icons.Info,
            warn = diagnostic_icons.Warn,
            error = diagnostic_icons.Error,
          },
        },
      },
    },
  },

  -- Buffer removal preserving window layout
  {
    "nvim-mini/mini.bufremove",
    config = function()
      require("mini.bufremove").setup()
    end,
  },

  -- Fuzzy finder
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-mini/mini.icons" },
    opts = {
      "default",
      winopts = { height = 0.85, width = 0.80 },
    },
  },

  -- Treesitter (parser installation + native TS highlighting)
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "lua", "vim", "vimdoc", "bash", "json", "yaml", "toml",
        "markdown", "markdown_inline", "python", "javascript", "typescript", "tsx",
        "html", "css", "go", "rust", "c", "cpp",
      },
    },
    config = function(_, opts)
      local ts = require("nvim-treesitter")
      ts.setup()
      ts.install(opts.ensure_installed)

      -- Enable Neovim's native Tree-sitter highlighter for buffers with
      -- available parsers. Keep this resilient for unsupported filetypes.
      local ts_hl_group = vim.api.nvim_create_augroup("nvim-ide-treesitter-highlight", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = ts_hl_group,
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },

  -- Indent guides
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {
      indent = { char = "│" },
      scope = { enabled = false },
      exclude = {
        filetypes = indent_exclude_filetypes,
      },
    },
  },

  -- Active indent scope (VS Code-like current block highlight)
  {
    "nvim-mini/mini.indentscope",
    opts = function()
      local indentscope = require("mini.indentscope")
      return {
        symbol = "│",
        draw = {
          delay = 60,
          animation = indentscope.gen_animation.none(),
        },
        options = { try_as_border = true },
        mappings = {
          object_scope = "",
          object_scope_with_border = "",
          goto_top = "",
          goto_bottom = "",
        },
      }
    end,
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = indent_exclude_filetypes,
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
    end,
  },

  -- Git gutter signs
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local map = function(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
        end
        map("n", "]h", gs.next_hunk, "Next hunk")
        map("n", "[h", gs.prev_hunk, "Previous hunk")
        map("n", "<leader>ghs", gs.stage_hunk, "Stage hunk")
        map("n", "<leader>ghr", gs.reset_hunk, "Reset hunk")
        map("n", "<leader>ghp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Blame line")
      end,
    },
  },

  -- LSP: mason + mason-lspconfig + lspconfig
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      {
        "mason-org/mason-lspconfig.nvim",
        opts = {
          ensure_installed = { "lua_ls" },
          automatic_enable = true,
        },
      },
      "saghen/blink.cmp",
    },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      for type, icon in pairs(diagnostic_icons) do
        local name = "DiagnosticSign" .. type
        vim.fn.sign_define(name, { text = icon, texthl = name, numhl = "" })
      end

      -- Apply blink.cmp capabilities to all LSP servers
      vim.lsp.config("*", { capabilities = capabilities })

      -- vtsls: prefer tsconfig.json so monorepo roots resolve correctly
      vim.lsp.config("vtsls", {
        root_dir = function(bufnr, on_dir)
          local util = require("lspconfig.util")
          local ts_root = util.root_pattern("tsconfig.json")
          local fallback_root = util.root_pattern("package.json", "jsconfig.json", ".git")

          local fname = vim.api.nvim_buf_get_name(bufnr)
          local root = ts_root(fname) or fallback_root(fname)
          return root and on_dir(root)
        end,
      })

      -- lua_ls: configure for Neovim runtime
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
    end,
  },

  -- Autocompletion
  {
    "saghen/blink.cmp",
    version = "1.*",
    opts = {
      keymap = {
        preset = "default",
        ["<CR>"] = { "accept", "fallback" },
      },
      appearance = { nerd_font_variant = "mono" },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
    },
  },

  -- Toggle comments
  {
    "numToStr/Comment.nvim",
    opts = {},
  },

  -- Auto-close brackets/quotes
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = { check_ts = true },
  },

  -- Copy file and line references (useful for sharing exact code locations)
  {
    "cajames/copy-reference.nvim",
    lazy = false,
    opts = {
      register = "+",
      use_git_root = true,
    },
    keys = {
      { "yr", "<cmd>CopyReference file<cr>", mode = { "n", "v" }, desc = "Copy file path" },
      { "yrr", "<cmd>CopyReference line<cr>", mode = { "n", "v" }, desc = "Copy file:line reference" },
    },
  },

  -- Keybinding discovery popup
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>f", group = "find/file" },
        { "<leader>c", group = "code" },
        { "<leader>g", group = "git" },
        { "<leader>b", group = "buffer" },
        { "<leader>s", group = "search" },
        { "<leader>u", group = "ui/toggle" },
        { "<leader>w", group = "window" },
        { "<leader>q", group = "quit" },
        { "<leader>gh", group = "hunks" },
      },
    },
  },
}, {
  install = {
    -- Prefer catppuccin during plugin installation when it's available.
    colorscheme = { "catppuccin", "habamax" },
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
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Buffer navigation
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "]b", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Switch to other buffer" })
map("n", "<leader>bd", function() require("mini.bufremove").wipeout(0, false) end, { desc = "Close buffer (keep layout)" })
map("n", "<leader>bo", "<cmd>%bdelete|edit #|bdelete #<cr>", { desc = "Close other buffers" })

-- File explorer
map("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "Toggle file explorer" })
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

-- LSP keybindings (buffer-local, set via LspAttach)
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("nvim-ide-lsp-attach", { clear = true }),
  callback = function(event)
    local buf = event.buf
    local lmap = function(mode, l, r, desc)
      vim.keymap.set(mode, l, r, { buffer = buf, desc = desc })
    end

    lmap("n", "gd", vim.lsp.buf.definition, "Go to definition")
    lmap("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
    lmap("n", "gI", vim.lsp.buf.implementation, "Go to implementation")
    lmap("n", "gy", vim.lsp.buf.type_definition, "Go to type definition")
    lmap("n", "gr", "<cmd>FzfLua lsp_references<cr>", "References")
    lmap("n", "K", vim.lsp.buf.hover, "Hover documentation")
    lmap("n", "<leader>cr", vim.lsp.buf.rename, "Rename symbol")
    lmap("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
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
    vim.bo.cinoptions = "l1,j1"
    -- Reindent on block delimiters/preprocessor/newline/else, but not on ":".
    -- Omitting ":" avoids extra reindent churn while typing labels/case lines.
    vim.bo.cinkeys = "0{,0},0),0],0#,!^F,o,O,e"
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("nvim-ide-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
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

-- Open an IDE-like layout when starting with a directory: tree left + editor right.
local function open_ide_layout()
  require("neo-tree.command").execute({ action = "show", dir = vim.uv.cwd() })
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
