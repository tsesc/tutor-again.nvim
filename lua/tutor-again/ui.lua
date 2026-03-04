local M = {}

local search = require("tutor-again.search")
local db = require("tutor-again.db")
local history = require("tutor-again.history")

local state = {
  input_buf = nil,
  input_win = nil,
  results_buf = nil,
  results_win = nil,
  current_results = {},
  selected_idx = 1,
  lang = nil, -- nil means use config default
  last_query = nil, -- preserve query when returning from detail
  last_selected_idx = nil,
}

local function get_lang()
  if state.lang then return state.lang end
  local config = require("tutor-again").config
  return config.lang or "zh-TW"
end

local function toggle_lang()
  local current = get_lang()
  if current == "zh-TW" then
    state.lang = "en"
  else
    state.lang = "zh-TW"
  end
end

local function entry_display_name(entry)
  if get_lang() == "zh-TW" then
    return entry.name_zh or entry.name
  else
    return entry.name
  end
end

local function lang_label()
  if get_lang() == "zh-TW" then return "中文" end
  return "EN"
end

local function short_category(cat)
  if not cat or cat == "" then return "" end
  -- Take top-level category only: "operators.delete" -> "operators"
  local top = cat:match("^([^.]+)")
  local map = {
    movement = "move",
    operators = "edit",
    text_objects = "text-obj",
    insert = "insert",
    visual = "visual",
    search = "search",
    files = "file",
    settings = "setting",
    plugins = "plugin",
  }
  return map[top] or top
end

local function close()
  if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
    vim.api.nvim_win_close(state.input_win, true)
  end
  if state.results_win and vim.api.nvim_win_is_valid(state.results_win) then
    vim.api.nvim_win_close(state.results_win, true)
  end
  state.input_win = nil
  state.results_win = nil
end

local function get_current_query()
  if not state.input_buf or not vim.api.nvim_buf_is_valid(state.input_buf) then return "" end
  local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, 1, false)
  return vim.fn.trim(lines[1] or "")
end

local function render_results(query)
  if not state.results_buf or not vim.api.nvim_buf_is_valid(state.results_buf) then return end

  local lines = {}
  if query == "" then
    -- Show history
    local entries = history.get_all()
    state.current_results = {}
    for i, entry in ipairs(entries) do
      if i > 20 then break end
      local time_str = history.format_time(entry.time)
      table.insert(lines, string.format("  %s%s%s", entry.query, string.rep(" ", math.max(1, 40 - #entry.query)), time_str))
      table.insert(state.current_results, { type = "history", query = entry.query })
    end
    if #lines == 0 then
      table.insert(lines, "  No history yet. Type to search!")
    end
  else
    -- Search database
    local entries = db.all()
    local results = search.filter_entries(query, entries)
    state.current_results = {}
    for i, entry in ipairs(results) do
      if i > 20 then break end
      local keys_col = 20
      local keys_str = entry.keys
      if #keys_str > keys_col - 1 then
        keys_str = keys_str:sub(1, keys_col - 2) .. "…"
      end
      local padding = string.rep(" ", math.max(1, keys_col - #keys_str))
      local cat = short_category(entry.category)
      local cat_col = 10
      if #cat > cat_col - 1 then
        cat = cat:sub(1, cat_col - 1)
      end
      local cat_pad = string.rep(" ", math.max(1, cat_col - #cat))
      local display = "  " .. keys_str .. padding .. cat .. cat_pad .. "│ " .. entry_display_name(entry)
      table.insert(lines, display)
      table.insert(state.current_results, { type = "entry", entry = entry })
    end
    if #lines == 0 then
      table.insert(lines, "  No results found.")
    end
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = state.results_buf })
  vim.api.nvim_buf_set_lines(state.results_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = state.results_buf })

  -- Highlight selected line
  state.selected_idx = 1
  M._highlight_selected()
end

function M._highlight_selected()
  if not state.results_buf or not vim.api.nvim_buf_is_valid(state.results_buf) then return end
  vim.api.nvim_buf_clear_namespace(state.results_buf, vim.api.nvim_create_namespace("tutor_again_sel"), 0, -1)
  local line_count = vim.api.nvim_buf_line_count(state.results_buf)
  if state.selected_idx >= 1 and state.selected_idx <= line_count then
    vim.api.nvim_buf_add_highlight(state.results_buf, vim.api.nvim_create_namespace("tutor_again_sel"), "CursorLine", state.selected_idx - 1, 0, -1)
    -- Scroll results window to keep selected line visible
    if state.results_win and vim.api.nvim_win_is_valid(state.results_win) then
      vim.api.nvim_win_set_cursor(state.results_win, { state.selected_idx, 0 })
    end
  end
end

local function update_input_title()
  if not state.input_win or not vim.api.nvim_win_is_valid(state.input_win) then return end
  vim.api.nvim_win_set_config(state.input_win, {
    title = string.format(" tutor-again [%s] <Tab>=lang ", lang_label()),
    title_pos = "center",
  })
end

local function on_select()
  local item = state.current_results[state.selected_idx]
  if not item then return end

  if item.type == "history" then
    -- Re-run this query
    close()
    M.open()
    vim.schedule(function()
      if state.input_buf and vim.api.nvim_buf_is_valid(state.input_buf) then
        vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { item.query })
        vim.api.nvim_win_set_cursor(state.input_win, { 1, #item.query })
        render_results(item.query)
      end
    end)
  elseif item.type == "entry" then
    local query = get_current_query()
    history.add(query)
    state.last_query = query
    state.last_selected_idx = state.selected_idx
    close()
    M.open_detail(item.entry)
  end
end

function M.open(opts)
  opts = opts or {}
  if vim.fn.getcmdwintype() ~= "" then return end
  close()

  local width = 70
  local total_height = 18
  local row = math.floor((vim.o.lines - total_height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Input buffer
  state.input_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = state.input_buf })

  state.input_win = vim.api.nvim_open_win(state.input_buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = 1,
    border = "rounded",
    title = string.format(" tutor-again [%s] <Tab>=lang ", lang_label()),
    title_pos = "center",
    style = "minimal",
  })

  -- Results buffer
  state.results_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = state.results_buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = state.results_buf })

  state.results_win = vim.api.nvim_open_win(state.results_buf, false, {
    relative = "editor",
    row = row + 3,
    col = col,
    width = width,
    height = total_height - 3,
    border = "rounded",
    style = "minimal",
  })

  vim.api.nvim_set_option_value("cursorline", false, { win = state.results_win })

  -- Initial render (show history)
  render_results("")

  -- Keymaps on input buffer
  local opts = { buffer = state.input_buf, nowait = true, silent = true }

  vim.keymap.set({ "i", "n" }, "<Esc>", close, opts)
  vim.keymap.set({ "i", "n" }, "<C-c>", close, opts)

  vim.keymap.set({ "i", "n" }, "<Down>", function()
    local line_count = vim.api.nvim_buf_line_count(state.results_buf)
    if state.selected_idx < line_count then
      state.selected_idx = state.selected_idx + 1
      M._highlight_selected()
    end
  end, opts)

  vim.keymap.set({ "i", "n" }, "<Up>", function()
    if state.selected_idx > 1 then
      state.selected_idx = state.selected_idx - 1
      M._highlight_selected()
    end
  end, opts)

  vim.keymap.set({ "i", "n" }, "<CR>", on_select, opts)

  vim.keymap.set({ "i", "n" }, "<Tab>", function()
    toggle_lang()
    update_input_title()
    render_results(get_current_query())
  end, opts)

  -- Live search on text change
  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = state.input_buf,
    callback = function()
      render_results(get_current_query())
    end,
  })

  -- Restore previous query when returning from detail
  if opts.restore then
    local q = state.last_query or ""
    local idx = state.last_selected_idx or 1
    if q ~= "" then
      vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { q })
      render_results(q)
      state.selected_idx = math.min(idx, #state.current_results)
      M._highlight_selected()
      vim.schedule(function()
        if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
          vim.api.nvim_win_set_cursor(state.input_win, { 1, #q })
        end
      end)
    end
  end

  vim.cmd("startinsert")
end

local function install_plugin(entry, win)
  if not entry.install then return end

  local config_dir = vim.fn.stdpath("config")
  local init_path = config_dir .. "/init.lua"
  local plugins_dir = config_dir .. "/lua/plugins"

  -- Special case: lazy.nvim bootstrap goes into init.lua
  if entry.keys == "lazy.nvim" then
    vim.fn.mkdir(config_dir, "p")
    vim.fn.mkdir(plugins_dir, "p")

    if vim.fn.filereadable(init_path) == 1 then
      local content = table.concat(vim.fn.readfile(init_path), "\n")
      if content:find("lazy%.nvim") then
        vim.notify("lazy.nvim already configured in init.lua", vim.log.levels.WARN)
        return
      end
      -- Append bootstrap to existing init.lua
      local new_content = content .. "\n\n" .. entry.install .. "\n"
      vim.fn.writefile(vim.split(new_content, "\n"), init_path)
    else
      -- Create init.lua with basic settings + bootstrap
      local starter = table.concat({
        "-- Basic settings",
        "vim.opt.number = true",
        "vim.opt.relativenumber = true",
        "vim.opt.termguicolors = true",
        "vim.opt.clipboard = 'unnamedplus'",
        "vim.opt.tabstop = 2",
        "vim.opt.shiftwidth = 2",
        "vim.opt.expandtab = true",
        "vim.opt.signcolumn = 'yes'",
        "vim.opt.cursorline = true",
        "vim.opt.scrolloff = 8",
        "vim.opt.ignorecase = true",
        "vim.opt.smartcase = true",
        "vim.opt.undofile = true",
        "",
        entry.install,
        "",
      }, "\n")
      vim.fn.writefile(vim.split(starter, "\n"), init_path)
    end
    -- Actually clone lazy.nvim right now if not already present
    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not vim.uv.fs_stat(lazypath) then
      vim.notify("Downloading lazy.nvim...", vim.log.levels.INFO)
      local result = vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", lazypath,
      })
      if vim.v.shell_error ~= 0 then
        vim.notify("Failed to clone lazy.nvim:\n" .. result, vim.log.levels.ERROR)
        return
      end
      vim.notify(
        "lazy.nvim installed!\n" .. init_path .. "\n\nRestart Neovim to activate.",
        vim.log.levels.INFO
      )
    else
      vim.notify("lazy.nvim already downloaded. Config written to:\n" .. init_path, vim.log.levels.INFO)
    end
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    return
  end

  -- Normal plugin: write to lua/plugins/{name}.lua
  vim.fn.mkdir(plugins_dir, "p")

  local name = entry.keys:gsub("%.nvim$", ""):gsub("[^%w_-]", "_"):lower()
  local filepath = plugins_dir .. "/" .. name .. ".lua"

  if vim.fn.filereadable(filepath) == 1 then
    vim.notify("Already installed: " .. filepath, vim.log.levels.WARN)
    return
  end

  -- Check if lazy.nvim is set up
  local has_lazy = false
  if vim.fn.filereadable(init_path) == 1 then
    local content = table.concat(vim.fn.readfile(init_path), "\n")
    has_lazy = content:find("lazy%.nvim") ~= nil
  end

  local install_code = entry.install
  if install_code:match("^%s*{") then
    install_code = "return " .. install_code
  end

  vim.fn.writefile(vim.split(install_code, "\n"), filepath)

  if has_lazy then
    -- Try to run :Lazy sync automatically if lazy.nvim is loaded
    local lazy_loaded = pcall(require, "lazy")
    if lazy_loaded then
      vim.notify("Installed! " .. filepath .. "\nRunning :Lazy sync ...", vim.log.levels.INFO)
      vim.schedule(function()
        vim.cmd("Lazy sync")
      end)
    else
      vim.notify("Installed! " .. filepath .. "\nRestart Neovim, then run :Lazy sync", vim.log.levels.INFO)
    end
  else
    vim.notify(
      "Installed! " .. filepath
        .. "\n\nlazy.nvim not found in init.lua."
        .. "\nInstall lazy.nvim first (search 'lazy.nvim' and press I).",
      vim.log.levels.WARN
    )
  end

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

function M.open_detail(entry)
  local width = 65
  local lines = {}
  local is_zh = get_lang() == "zh-TW"

  table.insert(lines, string.format("  %s — %s", entry.keys, entry_display_name(entry)))
  table.insert(lines, string.rep("─", width - 2))
  table.insert(lines, "")
  if entry.mnemonic then
    table.insert(lines, "  Mnemonic: " .. entry.mnemonic)
  end
  table.insert(lines, "")
  if entry.description then
    table.insert(lines, "  " .. entry.description)
  end
  table.insert(lines, "")
  if is_zh and entry.name_zh then
    table.insert(lines, "  " .. entry.name_zh)
    table.insert(lines, "")
  end
  if entry.install then
    table.insert(lines, "  Install (lazy.nvim):")
    table.insert(lines, "  " .. string.rep("─", 30))
    for install_line in entry.install:gmatch("[^\n]+") do
      table.insert(lines, "  " .. install_line)
    end
    table.insert(lines, "  " .. string.rep("─", 30))
    table.insert(lines, "")
  end
  if entry.related and #entry.related > 0 then
    table.insert(lines, "  Related:")
    for _, r in ipairs(entry.related) do
      table.insert(lines, "    • " .. r)
    end
  end
  table.insert(lines, "")
  table.insert(lines, "  Category: " .. (entry.category or ""))
  table.insert(lines, "")
  local hint = "  [q] close  [y] copy keys  [?] back  [Tab] lang"
  if entry.install then
    hint = "  [I] install  [Y] copy config  [y] copy keys  [?] back  [Tab] lang"
  end
  table.insert(lines, hint)

  local max_height = vim.o.lines - 6
  local height = math.min(#lines, max_height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = "rounded",
    title = string.format(" Detail [%s] ", lang_label()),
    title_pos = "center",
    style = "minimal",
  })

  vim.cmd("stopinsert")

  local opts = { buffer = buf, nowait = true, silent = true }

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, opts)

  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, opts)

  vim.keymap.set("n", "y", function()
    vim.fn.setreg("+", entry.keys)
    vim.notify("Copied: " .. entry.keys, vim.log.levels.INFO)
    vim.api.nvim_win_close(win, true)
    M.open({ restore = true })
  end, opts)

  if entry.install then
    vim.keymap.set("n", "Y", function()
      vim.fn.setreg("+", entry.install)
      vim.notify("Copied install config!", vim.log.levels.INFO)
      vim.api.nvim_win_close(win, true)
      M.open({ restore = true })
    end, opts)

    vim.keymap.set("n", "I", function()
      install_plugin(entry, win)
    end, opts)
  end

  vim.keymap.set("n", "?", function()
    vim.api.nvim_win_close(win, true)
    M.open({ restore = true })
  end, opts)

  vim.keymap.set("n", "<Tab>", function()
    toggle_lang()
    vim.api.nvim_win_close(win, true)
    M.open_detail(entry)
  end, opts)
end

function M.open_history()
  M.open()
end

function M.open_categories()
  vim.notify("tutor-again: categories coming soon", vim.log.levels.INFO)
end

return M
