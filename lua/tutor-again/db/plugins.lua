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

  -- ═══════════════════════════════════════════
  -- Plugin usage guides (no install field)
  -- ═══════════════════════════════════════════

  -- lazy.nvim usage
  { keys = ":Lazy", name = "Open lazy.nvim manager UI", name_zh = "開啟 lazy.nvim 管理介面", tags = { "lazy", "plugin", "manager", "ui", "套件", "管理", "介面" }, category = "plugins.usage.lazy", mnemonic = ":Lazy = plugin manager dashboard", description = "Open the lazy.nvim UI to install, update, clean, and check plugins." },
  { keys = ":Lazy sync", name = "Sync all plugins", name_zh = "同步所有套件（安裝+更新+清理）", tags = { "lazy", "sync", "update", "install", "同步", "更新", "安裝" }, category = "plugins.usage.lazy", mnemonic = ":Lazy sync = install + update + clean", description = "Install missing plugins, update existing ones, and remove unused ones." },
  { keys = ":Lazy update", name = "Update all plugins", name_zh = "更新所有套件", tags = { "lazy", "update", "更新", "套件" }, category = "plugins.usage.lazy", mnemonic = ":Lazy update = pull latest", description = "Update all installed plugins to their latest version." },
  { keys = ":Lazy clean", name = "Remove unused plugins", name_zh = "清除未使用的套件", tags = { "lazy", "clean", "remove", "清除", "移除" }, category = "plugins.usage.lazy", mnemonic = ":Lazy clean = remove orphans", description = "Remove plugins that are no longer in your config." },

  -- Neo-tree usage
  { keys = "<leader>e", name = "Toggle file explorer", name_zh = "開關檔案瀏覽器", tags = { "neo-tree", "file", "tree", "explorer", "toggle", "檔案", "瀏覽器", "開關" }, category = "plugins.usage.neo-tree", mnemonic = "<leader>e = explorer (if using neo-tree)", description = "Toggle the neo-tree file explorer sidebar. Default <leader> is \\ (recommend setting to Space)." },
  { keys = "<CR> (neo-tree)", name = "Open file / expand folder", name_zh = "開啟檔案 / 展開資料夾", tags = { "neo-tree", "open", "file", "folder", "expand", "開啟", "檔案", "資料夾", "展開" }, category = "plugins.usage.neo-tree", mnemonic = "Enter = open", description = "In neo-tree: open the file or expand/collapse the folder under cursor." },
  { keys = "a (neo-tree)", name = "Add file or directory", name_zh = "新增檔案或資料夾", tags = { "neo-tree", "add", "new", "file", "directory", "folder", "create", "新增", "檔案", "資料夾", "建立" }, category = "plugins.usage.neo-tree", mnemonic = "a = add (end with / for directory)", description = "In neo-tree: create a new file. Add trailing / to create a directory instead." },
  { keys = "d (neo-tree)", name = "Delete file", name_zh = "刪除檔案", tags = { "neo-tree", "delete", "remove", "file", "刪除", "檔案" }, category = "plugins.usage.neo-tree", mnemonic = "d = delete", description = "In neo-tree: delete the file or directory under cursor (with confirmation)." },
  { keys = "r (neo-tree)", name = "Rename file", name_zh = "重新命名檔案", tags = { "neo-tree", "rename", "file", "重新命名", "改名", "檔案" }, category = "plugins.usage.neo-tree", mnemonic = "r = rename", description = "In neo-tree: rename the file or directory under cursor." },
  { keys = "c (neo-tree)", name = "Copy file", name_zh = "複製檔案", tags = { "neo-tree", "copy", "file", "複製", "檔案" }, category = "plugins.usage.neo-tree", mnemonic = "c = copy", description = "In neo-tree: copy the file under cursor to a new location." },
  { keys = "m (neo-tree)", name = "Move file", name_zh = "移動檔案", tags = { "neo-tree", "move", "file", "移動", "檔案" }, category = "plugins.usage.neo-tree", mnemonic = "m = move", description = "In neo-tree: move the file under cursor to a new location." },
  { keys = "R (neo-tree)", name = "Refresh file tree", name_zh = "重新整理檔案樹", tags = { "neo-tree", "refresh", "reload", "重新整理", "刷新" }, category = "plugins.usage.neo-tree", mnemonic = "R = refresh", description = "In neo-tree: refresh the file tree to reflect filesystem changes." },
  { keys = "? (neo-tree)", name = "Show neo-tree help", name_zh = "顯示 neo-tree 快捷鍵說明", tags = { "neo-tree", "help", "keys", "說明", "快捷鍵" }, category = "plugins.usage.neo-tree", mnemonic = "? = help in neo-tree", description = "In neo-tree: show all available keybindings." },
  { keys = "H (neo-tree)", name = "Toggle hidden files", name_zh = "顯示/隱藏隱藏檔", tags = { "neo-tree", "hidden", "dotfile", "toggle", "隱藏檔", "顯示" }, category = "plugins.usage.neo-tree", mnemonic = "H = hidden files", description = "In neo-tree: toggle visibility of hidden/dot files." },
  { keys = "P (neo-tree)", name = "Preview file", name_zh = "預覽檔案", tags = { "neo-tree", "preview", "file", "預覽", "檔案" }, category = "plugins.usage.neo-tree", mnemonic = "P = preview without opening", description = "In neo-tree: preview file content without leaving the tree." },

  -- Telescope usage
  { keys = "<leader>ff", name = "Find files", name_zh = "搜尋檔案", tags = { "telescope", "find", "file", "搜尋", "檔案" }, category = "plugins.usage.telescope", mnemonic = "ff = find files", description = "Open Telescope file finder. Type to fuzzy-search file names." },
  { keys = "<leader>fg", name = "Live grep (search text)", name_zh = "全域文字搜尋", tags = { "telescope", "grep", "search", "text", "搜尋", "文字", "全域" }, category = "plugins.usage.telescope", mnemonic = "fg = find grep", description = "Search text across all files using live grep. Requires ripgrep." },
  { keys = "<leader>fb", name = "Browse buffers", name_zh = "瀏覽已開啟的 buffer", tags = { "telescope", "buffer", "browse", "瀏覽", "緩衝區" }, category = "plugins.usage.telescope", mnemonic = "fb = find buffer", description = "List and switch between open buffers." },
  { keys = "<leader>fh", name = "Search help tags", name_zh = "搜尋說明文件", tags = { "telescope", "help", "search", "doc", "搜尋", "說明", "文件" }, category = "plugins.usage.telescope", mnemonic = "fh = find help", description = "Search Neovim help documentation." },
  { keys = "<C-p> (telescope)", name = "Scroll up in preview", name_zh = "在預覽中向上捲動", tags = { "telescope", "scroll", "preview", "up", "預覽", "捲動" }, category = "plugins.usage.telescope", mnemonic = "Ctrl-p = preview up (in telescope)", description = "In Telescope: scroll the preview pane up." },
  { keys = "<C-n> (telescope)", name = "Next result / scroll down", name_zh = "下一個結果", tags = { "telescope", "next", "down", "scroll", "下一個" }, category = "plugins.usage.telescope", mnemonic = "Ctrl-n = next (in telescope)", description = "In Telescope: move to next result in the list." },

  -- Mason usage
  { keys = ":Mason", name = "Open Mason installer UI", name_zh = "開啟 Mason 安裝管理介面", tags = { "mason", "install", "lsp", "ui", "安裝", "管理" }, category = "plugins.usage.mason", mnemonic = ":Mason = LSP/tool installer UI", description = "Open Mason UI to browse, install, and manage LSP servers, formatters, and linters." },
  { keys = ":MasonInstall {name}", name = "Install a tool via Mason", name_zh = "用 Mason 安裝工具", tags = { "mason", "install", "安裝" }, category = "plugins.usage.mason", mnemonic = ":MasonInstall lua-language-server", description = "Install a specific LSP server, formatter, or linter. e.g. :MasonInstall pyright" },

  -- LSP usage
  { keys = "gd (LSP)", name = "Go to definition", name_zh = "跳到定義", tags = { "lsp", "definition", "goto", "跳", "定義" }, category = "plugins.usage.lsp", mnemonic = "gd = go definition (LSP)", description = "Jump to where the symbol under cursor is defined. Requires LSP server running." },
  { keys = "K (LSP)", name = "Hover documentation", name_zh = "顯示懸停文件", tags = { "lsp", "hover", "doc", "help", "文件", "說明", "懸停" }, category = "plugins.usage.lsp", mnemonic = "K = show docs (LSP)", description = "Show documentation/type info for the symbol under cursor in a floating window." },
  { keys = "<leader>rn (LSP)", name = "Rename symbol", name_zh = "重新命名符號", tags = { "lsp", "rename", "refactor", "重新命名", "重構" }, category = "plugins.usage.lsp", mnemonic = "rn = rename (LSP)", description = "Rename the symbol under cursor across the entire project." },
  { keys = "<leader>ca (LSP)", name = "Code action", name_zh = "程式碼動作", tags = { "lsp", "code", "action", "fix", "quickfix", "程式碼", "動作", "修復" }, category = "plugins.usage.lsp", mnemonic = "ca = code action (LSP)", description = "Show available code actions (auto-fix, refactor, extract) for the current position." },
  { keys = "gl (LSP)", name = "Show line diagnostics", name_zh = "顯示當前行的診斷訊息", tags = { "lsp", "diagnostic", "error", "warning", "line", "診斷", "錯誤", "警告" }, category = "plugins.usage.lsp", mnemonic = "gl = line diagnostic (LSP)", description = "Show diagnostic messages (errors, warnings) for the current line in a floating window." },
  { keys = "]d (LSP)", name = "Next diagnostic", name_zh = "下一個診斷訊息", tags = { "lsp", "diagnostic", "next", "error", "診斷", "下一個" }, category = "plugins.usage.lsp", mnemonic = "]d = next diagnostic (LSP)", description = "Jump to the next diagnostic (error/warning) in the buffer." },
  { keys = "[d (LSP)", name = "Previous diagnostic", name_zh = "上一個診斷訊息", tags = { "lsp", "diagnostic", "previous", "error", "診斷", "上一個" }, category = "plugins.usage.lsp", mnemonic = "[d = prev diagnostic (LSP)", description = "Jump to the previous diagnostic (error/warning) in the buffer." },
  { keys = "gr (LSP)", name = "Find references", name_zh = "查找所有參考", tags = { "lsp", "references", "find", "usage", "參考", "查找", "使用" }, category = "plugins.usage.lsp", mnemonic = "gr = go references (LSP)", description = "Find all references to the symbol under cursor across the project." },

  -- Gitsigns usage
  { keys = "]c (gitsigns)", name = "Next git hunk", name_zh = "下一個 Git 變更區塊", tags = { "git", "gitsigns", "hunk", "next", "diff", "變更", "下一個" }, category = "plugins.usage.gitsigns", mnemonic = "]c = next change", description = "Jump to the next git change hunk in the buffer." },
  { keys = "[c (gitsigns)", name = "Previous git hunk", name_zh = "上一個 Git 變更區塊", tags = { "git", "gitsigns", "hunk", "previous", "diff", "變更", "上一個" }, category = "plugins.usage.gitsigns", mnemonic = "[c = prev change", description = "Jump to the previous git change hunk in the buffer." },
  { keys = "<leader>hs (gitsigns)", name = "Stage hunk", name_zh = "暫存變更區塊", tags = { "git", "gitsigns", "stage", "hunk", "暫存", "變更" }, category = "plugins.usage.gitsigns", mnemonic = "hs = hunk stage", description = "Stage the git hunk under cursor (like git add for just this change)." },
  { keys = "<leader>hr (gitsigns)", name = "Reset hunk", name_zh = "還原變更區塊", tags = { "git", "gitsigns", "reset", "hunk", "undo", "還原", "變更" }, category = "plugins.usage.gitsigns", mnemonic = "hr = hunk reset", description = "Discard the git hunk under cursor (revert to last commit)." },
  { keys = "<leader>hb (gitsigns)", name = "Blame current line", name_zh = "顯示當前行的 Git blame", tags = { "git", "gitsigns", "blame", "line", "author", "blame", "作者" }, category = "plugins.usage.gitsigns", mnemonic = "hb = hunk blame", description = "Show git blame info for the current line (who changed it and when)." },

  -- Comment.nvim usage
  { keys = "gcc", name = "Toggle line comment", name_zh = "切換行註解", tags = { "comment", "toggle", "line", "註解", "切換", "行" }, category = "plugins.usage.comment", mnemonic = "gcc = go comment comment", description = "Toggle comment on the current line. Requires Comment.nvim plugin." },
  { keys = "gc{motion}", name = "Toggle comment with motion", name_zh = "用動作切換註解", tags = { "comment", "toggle", "motion", "block", "註解", "切換" }, category = "plugins.usage.comment", mnemonic = "gc = go comment + motion", description = "Toggle comment for the range of {motion}. e.g. gcap = comment paragraph, gc3j = comment 3 lines down." },
  { keys = "gbc", name = "Toggle block comment", name_zh = "切換區塊註解", tags = { "comment", "block", "toggle", "註解", "區塊" }, category = "plugins.usage.comment", mnemonic = "gbc = go block comment", description = "Toggle block comment (/* */) on the current line. Requires Comment.nvim." },
}
