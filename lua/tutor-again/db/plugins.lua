return {
  -- Plugin manager
  {
    keys = "lazy.nvim",
    name = "Plugin manager",
    name_zh = "套件管理器",
    tags = { "plugin", "manager", "install", "lazy", "套件", "管理", "安裝" },
    category = "plugins.core",
    mnemonic = "The standard Neovim plugin manager",
    description = "Modern plugin manager with lazy-loading, lockfile, and UI. Install by adding bootstrap code to init.lua.",
    install = [[-- Bootstrap (add to top of init.lua)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)
require("lazy").setup("plugins") -- loads lua/plugins/*.lua]],
  },

  -- Fuzzy finder
  {
    keys = "telescope.nvim",
    name = "Fuzzy finder",
    name_zh = "模糊搜尋器",
    tags = { "telescope", "fuzzy", "find", "file", "grep", "picker", "模糊", "搜尋", "檔案" },
    category = "plugins.core",
    mnemonic = "The Swiss army knife of fuzzy finding",
    description = "Highly extendable fuzzy finder for files, grep, buffers, git, and more.",
    install = [[{
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
    { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
    { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help" },
  },
}]],
  },

  -- Treesitter
  {
    keys = "nvim-treesitter",
    name = "Treesitter syntax engine",
    name_zh = "Treesitter 語法引擎",
    tags = { "treesitter", "syntax", "highlight", "parser", "語法", "高亮", "解析" },
    category = "plugins.core",
    mnemonic = "Better syntax highlighting via parsing",
    description = "Provides fast, accurate syntax highlighting, indentation, and text objects using tree-sitter parsers.",
    install = [[{
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = { "lua", "vim", "vimdoc", "javascript",
        "typescript", "python", "html", "css", "json", "yaml",
        "markdown", "bash" },
      highlight = { enable = true },
      indent = { enable = true },
    })
  end,
}]],
  },

  -- LSP
  {
    keys = "nvim-lspconfig",
    name = "LSP configuration",
    name_zh = "LSP 語言伺服器設定",
    tags = { "lsp", "language", "server", "completion", "diagnostic", "語言", "伺服器", "補全", "診斷" },
    category = "plugins.core",
    mnemonic = "Connect Neovim to language servers",
    description = "Quickstart configs for Neovim's built-in LSP client. Provides go-to-definition, diagnostics, hover, etc.",
    install = [[{
  "neovim/nvim-lspconfig",
  config = function()
    local lspconfig = require("lspconfig")
    -- Example: Lua LS
    lspconfig.lua_ls.setup({})
    -- Example: TypeScript
    lspconfig.ts_ls.setup({})
    -- Keymaps (set in on_attach or globally)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition)
    vim.keymap.set("n", "K", vim.lsp.buf.hover)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action)
  end,
}]],
  },

  -- Mason
  {
    keys = "mason.nvim",
    name = "LSP/tool installer",
    name_zh = "LSP 與工具安裝管理器",
    tags = { "mason", "install", "lsp", "server", "formatter", "linter", "安裝", "管理" },
    category = "plugins.core",
    mnemonic = "Install LSP servers, formatters, linters from UI",
    description = "Portable package manager for LSP servers, DAP servers, linters, and formatters. Use :Mason to open UI.",
    install = [[{
  "williamboman/mason.nvim",
  dependencies = { "williamboman/mason-lspconfig.nvim" },
  config = function()
    require("mason").setup()
    require("mason-lspconfig").setup({
      ensure_installed = { "lua_ls", "ts_ls", "pyright" },
    })
  end,
}]],
  },

  -- Completion
  {
    keys = "nvim-cmp",
    name = "Auto completion engine",
    name_zh = "自動補全引擎",
    tags = { "cmp", "completion", "auto", "snippet", "補全", "自動", "片段" },
    category = "plugins.core",
    mnemonic = "The completion framework for Neovim",
    description = "Extensible completion engine. Sources: LSP, buffer, path, snippets.",
    install = [[{
  "hrsh7th/nvim-cmp",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "L3MON4D3/LuaSnip",
    "saadparwaiz1/cmp_luasnip",
  },
  config = function()
    local cmp = require("cmp")
    cmp.setup({
      snippet = {
        expand = function(args)
          require("luasnip").lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<CR>"] = cmp.mapping.confirm({ select = true }),
      }),
      sources = {
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "buffer" },
        { name = "path" },
      },
    })
  end,
}]],
  },

  -- LuaSnip
  {
    keys = "LuaSnip",
    name = "Snippet engine",
    name_zh = "程式碼片段引擎",
    tags = { "snippet", "luasnip", "template", "片段", "模板" },
    category = "plugins.core",
    mnemonic = "Fast snippet engine in Lua",
    description = "Snippet engine that supports LSP snippets, VS Code snippets, and custom snippets.",
    install = [[{
  "L3MON4D3/LuaSnip",
  dependencies = { "rafamadriz/friendly-snippets" },
  config = function()
    require("luasnip.loaders.from_vscode").lazy_load()
  end,
}]],
  },

  -- Git signs
  {
    keys = "gitsigns.nvim",
    name = "Git signs in gutter",
    name_zh = "Git 狀態標記（行號旁）",
    tags = { "git", "signs", "gutter", "diff", "hunk", "blame", "Git", "標記", "差異" },
    category = "plugins.productivity",
    mnemonic = "See git changes in the sign column",
    description = "Shows git diff markers in the sign column. Stage/reset hunks, inline blame, etc.",
    install = [[{
  "lewis6991/gitsigns.nvim",
  config = function()
    require("gitsigns").setup({
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        vim.keymap.set("n", "]c", gs.next_hunk, { buffer = bufnr })
        vim.keymap.set("n", "[c", gs.prev_hunk, { buffer = bufnr })
        vim.keymap.set("n", "<leader>hs", gs.stage_hunk, { buffer = bufnr })
        vim.keymap.set("n", "<leader>hr", gs.reset_hunk, { buffer = bufnr })
        vim.keymap.set("n", "<leader>hb", gs.blame_line, { buffer = bufnr })
      end,
    })
  end,
}]],
  },

  -- Status line
  {
    keys = "lualine.nvim",
    name = "Status line",
    name_zh = "狀態列",
    tags = { "status", "line", "bar", "lualine", "狀態列", "狀態欄" },
    category = "plugins.productivity",
    mnemonic = "Beautiful and fast status line",
    description = "Fast and configurable status line plugin written in Lua.",
    install = [[{
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("lualine").setup({
      options = { theme = "auto" },
    })
  end,
}]],
  },

  -- File tree
  {
    keys = "neo-tree.nvim",
    name = "File tree explorer",
    name_zh = "檔案樹瀏覽器",
    tags = { "file", "tree", "explorer", "sidebar", "neo-tree", "檔案", "樹", "瀏覽", "側邊欄" },
    category = "plugins.productivity",
    mnemonic = "File tree in a sidebar",
    description = "File explorer with git status, diagnostics, and floating window support.",
    install = [[{
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  keys = {
    { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "File explorer" },
  },
}]],
  },

  -- Auto pairs
  {
    keys = "nvim-autopairs",
    name = "Auto close brackets",
    name_zh = "自動關閉括號",
    tags = { "auto", "pairs", "bracket", "close", "parenthesis", "自動", "括號", "配對" },
    category = "plugins.productivity",
    mnemonic = "Auto-insert matching bracket",
    description = "Automatically insert closing brackets, quotes, etc.",
    install = [[{
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  config = true,  -- uses default settings
}]],
  },

  -- Comment
  {
    keys = "Comment.nvim",
    name = "Toggle comments",
    name_zh = "切換註解",
    tags = { "comment", "toggle", "line", "block", "註解", "切換", "註釋" },
    category = "plugins.productivity",
    mnemonic = "gcc to comment, gc{motion} for range",
    description = "Smart comment toggling. gcc for line, gc{motion} for range, gbc for block comment.",
    install = [[{
  "numToStr/Comment.nvim",
  keys = {
    { "gcc", mode = "n", desc = "Comment line" },
    { "gc", mode = { "n", "v" }, desc = "Comment" },
  },
  config = true,
}]],
  },

  -- Which key
  {
    keys = "which-key.nvim",
    name = "Keybinding hints",
    name_zh = "按鍵提示面板",
    tags = { "which", "key", "hint", "keybind", "popup", "按鍵", "提示", "快捷鍵" },
    category = "plugins.productivity",
    mnemonic = "Shows available keybindings in popup",
    description = "Displays a popup with possible keybindings after pressing a key prefix (e.g. <leader>).",
    install = [[{
  "folke/which-key.nvim",
  event = "VeryLazy",
  config = true,
}]],
  },

  -- Formatter
  {
    keys = "conform.nvim",
    name = "Code formatter",
    name_zh = "程式碼格式化工具",
    tags = { "format", "formatter", "prettier", "stylua", "conform", "格式化", "格式" },
    category = "plugins.productivity",
    mnemonic = "Format code on save",
    description = "Lightweight formatter plugin. Supports format-on-save with multiple formatters per filetype.",
    install = [[{
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  keys = {
    { "<leader>f", function()
      require("conform").format({ async = true })
    end, desc = "Format" },
  },
  config = function()
    require("conform").setup({
      formatters_by_ft = {
        lua = { "stylua" },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        python = { "ruff_format" },
      },
      format_on_save = { timeout_ms = 500 },
    })
  end,
}]],
  },

  -- Color scheme
  {
    keys = "catppuccin.nvim",
    name = "Catppuccin color scheme",
    name_zh = "Catppuccin 配色方案",
    tags = { "color", "scheme", "theme", "catppuccin", "配色", "主題", "顏色" },
    category = "plugins.appearance",
    mnemonic = "Soothing pastel theme",
    description = "Popular color scheme with 4 flavors: latte (light), frappe, macchiato, mocha (dark).",
    install = [[{
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,  -- load before other plugins
  config = function()
    vim.cmd.colorscheme("catppuccin-mocha")
  end,
}]],
  },

  -- Indent guides
  {
    keys = "indent-blankline.nvim",
    name = "Indent guide lines",
    name_zh = "縮排參考線",
    tags = { "indent", "guide", "line", "blank", "縮排", "參考線", "對齊" },
    category = "plugins.appearance",
    mnemonic = "Visual indent guides",
    description = "Displays indent guides (vertical lines) to visualize indentation levels.",
    install = [[{
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  config = true,
}]],
  },

  -- Noice
  {
    keys = "noice.nvim",
    name = "Better UI for messages/cmdline",
    name_zh = "美化訊息與指令列",
    tags = { "noice", "ui", "message", "cmdline", "notify", "美化", "訊息", "指令列" },
    category = "plugins.appearance",
    mnemonic = "Replaces messages, cmdline, popupmenu",
    description = "Replaces the default UI for messages, cmdline, and popupmenu with modern floating windows.",
    install = [[{
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify",
  },
  config = true,
}]],
  },

  -- Web devicons
  {
    keys = "nvim-web-devicons",
    name = "File type icons",
    name_zh = "檔案類型圖示",
    tags = { "icon", "devicons", "file", "type", "圖示", "圖標", "檔案" },
    category = "plugins.appearance",
    mnemonic = "Icons for file types in tree/tabs/statusline",
    description = "Provides file type icons. Required by many plugins (telescope, neo-tree, lualine, bufferline).",
    install = [[{
  "nvim-tree/nvim-web-devicons",
  -- Usually added as a dependency, not standalone
}]],
  },

  -- Bufferline
  {
    keys = "bufferline.nvim",
    name = "Tab-style buffer line",
    name_zh = "分頁式 buffer 列",
    tags = { "buffer", "tab", "line", "bar", "bufferline", "分頁", "標籤", "列" },
    category = "plugins.appearance",
    mnemonic = "Buffer tabs at the top",
    description = "Show open buffers as tabs at the top of the screen. Supports mouse, reordering, and custom sections.",
    install = [[{
  "akinsho/bufferline.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("bufferline").setup({})
  end,
}]],
  },

  -- Dashboard
  {
    keys = "dashboard-nvim",
    name = "Start screen dashboard",
    name_zh = "啟動畫面",
    tags = { "dashboard", "start", "screen", "home", "啟動", "畫面", "首頁" },
    category = "plugins.appearance",
    mnemonic = "Fancy start screen with shortcuts",
    description = "Customizable start screen with recent files, shortcuts, and project bookmarks.",
    install = [[{
  "nvimdev/dashboard-nvim",
  event = "VimEnter",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("dashboard").setup({
      theme = "hyper",  -- or "doom"
    })
  end,
}]],
  },
}
