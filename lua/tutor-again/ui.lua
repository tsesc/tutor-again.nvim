local M = {}

local search = require("tutor-again.search")
local db = require("tutor-again.db")
local history = require("tutor-again.history")
local ai_history = require("tutor-again.ai_history")

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
  mode = "search", -- "search" or "ai"
  ai_job_id = nil,
  ai_response = "",
  ai_showing_history = false,  -- true when displaying AI history list in AI mode
  ai_history_results = {},     -- current AI history entries being shown
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

local function mode_label()
  if state.mode == "ai" then return "AI" end
  return get_lang() == "zh-TW" and "搜尋" or "Search"
end

local function short_category(cat)
  if not cat or cat == "" then return "" end
  -- Take top-level category only: "operators.delete" -> "operators"
  local top = cat:match("^([^.]+)")
  if get_lang() == "zh-TW" then
    local map_zh = {
      movement = "移動",
      operators = "編輯",
      text_objects = "文字",
      insert = "插入",
      visual = "選取",
      search = "搜尋",
      files = "檔案",
      settings = "設定",
      plugins = "插件",
    }
    return map_zh[top] or top
  end
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
  if state.ai_job_id then
    require("tutor-again.ai").cancel(state.ai_job_id)
    state.ai_job_id = nil
  end
  if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
    vim.api.nvim_win_close(state.input_win, true)
  end
  if state.results_win and vim.api.nvim_win_is_valid(state.results_win) then
    vim.api.nvim_win_close(state.results_win, true)
  end
  state.input_win = nil
  state.results_win = nil
  state.ai_response = ""
  state.ai_showing_history = false
  state.ai_history_results = {}
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
      local time_str = history.format_time(entry.time, get_lang())
      table.insert(lines, string.format("  %s%s%s", entry.query, string.rep(" ", math.max(1, 40 - #entry.query)), time_str))
      table.insert(state.current_results, { type = "history", query = entry.query })
    end
    if #lines == 0 then
      if get_lang() == "zh-TW" then
        table.insert(lines, "  尚無歷史紀錄，輸入關鍵字搜尋！")
      else
        table.insert(lines, "  No history yet. Type to search!")
      end
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
      if get_lang() == "zh-TW" then
        table.insert(lines, "  找不到結果")
      else
        table.insert(lines, "  No results found.")
      end
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

local function get_mode_key_label()
  local config = require("tutor-again").config
  local key = config.ai and config.ai.mode_key or "<C-a>"
  -- Convert <C-a> to Ctrl+a for display
  local label = key:gsub("<C%-(%w)>", "C-%1")
  return label
end

local function build_hints()
  local mode_key = get_mode_key_label()
  local is_zh = get_lang() == "zh-TW"
  if state.mode == "ai" then
    if is_zh then
      return string.format(" %s=搜尋 Tab=語言 C-y=複製 C-d=刪除 ", mode_key)
    else
      return string.format(" %s=search Tab=lang C-y=copy C-d=del ", mode_key)
    end
  else
    if is_zh then
      return string.format(" %s=AI Tab=語言 ", mode_key)
    else
      return string.format(" %s=AI Tab=lang ", mode_key)
    end
  end
end

local function update_input_title()
  if not state.input_win or not vim.api.nvim_win_is_valid(state.input_win) then return end
  vim.api.nvim_win_set_config(state.input_win, {
    title = string.format(" tutor-again %s [%s] ", mode_label(), lang_label()),
    title_pos = "center",
    footer = build_hints(),
    footer_pos = "center",
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

local function set_results_lines(lines)
  if not state.results_buf or not vim.api.nvim_buf_is_valid(state.results_buf) then return end
  vim.api.nvim_set_option_value("modifiable", true, { buf = state.results_buf })
  vim.api.nvim_buf_set_lines(state.results_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = state.results_buf })
end

local function show_ai_placeholder()
  local placeholder
  if get_lang() == "zh-TW" then
    placeholder = "  輸入 Vim 相關問題，按 Enter 送出"
  else
    placeholder = "  Type a Vim question, press Enter to ask"
  end
  set_results_lines({ placeholder })
end

local function render_ai_history()
  if not state.results_buf or not vim.api.nvim_buf_is_valid(state.results_buf) then return end

  local entries = ai_history.get_all()
  local lines = {}
  state.ai_history_results = {}

  for i, entry in ipairs(entries) do
    if i > 20 then break end
    local time_str = history.format_time(entry.timestamp, get_lang())
    local q = entry.question
    local max_q_width = 40
    -- Truncate by display width (CJK chars = 2 columns)
    local qw = vim.api.nvim_strwidth(q)
    if qw > max_q_width then
      -- Trim until display width fits
      while vim.api.nvim_strwidth(q) > max_q_width - 1 do
        q = vim.fn.strcharpart(q, 0, vim.fn.strchars(q) - 1)
      end
      q = q .. "…"
      qw = vim.api.nvim_strwidth(q)
    end
    table.insert(lines, string.format("  %s%s%s", q, string.rep(" ", math.max(1, max_q_width + 2 - qw)), time_str))
    table.insert(state.ai_history_results, entry)
  end

  if #lines == 0 then
    state.ai_showing_history = false
    show_ai_placeholder()
    return
  end

  state.ai_showing_history = true
  state.selected_idx = 1

  vim.api.nvim_set_option_value("modifiable", true, { buf = state.results_buf })
  vim.api.nvim_buf_set_lines(state.results_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = state.results_buf })

  M._highlight_selected()
end

local function update_results_footer()
  if not state.results_win or not vim.api.nvim_win_is_valid(state.results_win) then return end
  local footer = state.mode == "ai"
    and (get_lang() == "zh-TW" and " AI 生成，僅供參考 " or " AI-generated, verify before use ")
    or (get_lang() == "zh-TW" and " Up/Down=捲動 " or " Up/Down=scroll ")
  vim.api.nvim_win_set_config(state.results_win, { footer = footer, footer_pos = "center" })
end

local function toggle_mode()
  if state.mode == "search" then
    state.mode = "ai"
    render_ai_history()
  else
    state.mode = "search"
    state.ai_showing_history = false
    state.ai_history_results = {}
    render_results(get_current_query())
  end
  update_input_title()
  update_results_footer()
  -- Clear input when switching modes
  if state.input_buf and vim.api.nvim_buf_is_valid(state.input_buf) then
    vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "" })
  end
end

local function send_ai_query()
  local ai = require("tutor-again.ai")
  local query = get_current_query()
  if query == "" then return end

  -- Cancel existing job
  if state.ai_job_id then
    ai.cancel(state.ai_job_id)
    state.ai_job_id = nil
  end

  state.ai_response = ""
  state.ai_showing_history = false
  state.ai_history_results = {}
  local thinking
  if get_lang() == "zh-TW" then
    thinking = "  思考中..."
  else
    thinking = "  Thinking..."
  end
  set_results_lines({ thinking })

  state.ai_job_id = ai.ask(query, get_lang(), {
    on_chunk = function(content)
      state.ai_response = state.ai_response .. content
      local wrapped = ai.wrap_text(state.ai_response, 64)
      -- Add 2-space indent
      local display = {}
      for _, line in ipairs(wrapped) do
        table.insert(display, "  " .. line)
      end
      set_results_lines(display)
      -- Scroll to bottom
      if state.results_win and vim.api.nvim_win_is_valid(state.results_win) then
        local count = vim.api.nvim_buf_line_count(state.results_buf)
        pcall(vim.api.nvim_win_set_cursor, state.results_win, { count, 0 })
      end
    end,
    on_done = function()
      state.ai_job_id = nil
      if state.ai_response ~= "" then
        local config = require("tutor-again").config
        local max = config.ai and config.ai.history_max_entries
        if max ~= 0 then
          ai_history.add(query, state.ai_response, get_lang())
        end
      end
    end,
    on_error = function(msg)
      state.ai_job_id = nil
      local prefix = get_lang() == "zh-TW" and "  錯誤: " or "  Error: "
      set_results_lines({ prefix .. msg })
    end,
  })
end

function M.open(opts)
  opts = opts or {}
  if vim.fn.getcmdwintype() ~= "" then return end
  close()

  -- Set initial mode if specified
  if opts.mode == "ai" then
    state.mode = "ai"
  elseif not opts.restore then
    state.mode = "search"
  end

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
    title = string.format(" tutor-again %s [%s] ", mode_label(), lang_label()),
    title_pos = "center",
    footer = build_hints(),
    footer_pos = "center",
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
    footer = state.mode == "ai"
      and (get_lang() == "zh-TW" and " AI 生成，僅供參考 " or " AI-generated, verify before use ")
      or (get_lang() == "zh-TW" and " Up/Down=捲動 " or " Up/Down=scroll "),
    footer_pos = "center",
    style = "minimal",
  })

  vim.api.nvim_set_option_value("cursorline", false, { win = state.results_win })

  -- Initial render based on mode
  if state.mode == "ai" then
    render_ai_history()
  else
    render_results("")
  end

  -- Keymaps on input buffer
  local kopts = { buffer = state.input_buf, nowait = true, silent = true }

  vim.keymap.set({ "i", "n" }, "<Esc>", close, kopts)
  vim.keymap.set({ "i", "n" }, "<C-c>", close, kopts)

  vim.keymap.set({ "i", "n" }, "<Down>", function()
    if state.mode == "ai" then
      if state.ai_showing_history then
        local line_count = vim.api.nvim_buf_line_count(state.results_buf)
        if state.selected_idx < line_count then
          state.selected_idx = state.selected_idx + 1
          M._highlight_selected()
        end
      else
        if state.results_win and vim.api.nvim_win_is_valid(state.results_win) then
          local count = vim.api.nvim_buf_line_count(state.results_buf)
          local cursor = vim.api.nvim_win_get_cursor(state.results_win)
          if cursor[1] < count then
            pcall(vim.api.nvim_win_set_cursor, state.results_win, { cursor[1] + 1, 0 })
          end
        end
      end
    else
      local line_count = vim.api.nvim_buf_line_count(state.results_buf)
      if state.selected_idx < line_count then
        state.selected_idx = state.selected_idx + 1
        M._highlight_selected()
      end
    end
  end, kopts)

  vim.keymap.set({ "i", "n" }, "<Up>", function()
    if state.mode == "ai" then
      if state.ai_showing_history then
        if state.selected_idx > 1 then
          state.selected_idx = state.selected_idx - 1
          M._highlight_selected()
        end
      else
        if state.results_win and vim.api.nvim_win_is_valid(state.results_win) then
          local cursor = vim.api.nvim_win_get_cursor(state.results_win)
          if cursor[1] > 1 then
            pcall(vim.api.nvim_win_set_cursor, state.results_win, { cursor[1] - 1, 0 })
          end
        end
      end
    else
      if state.selected_idx > 1 then
        state.selected_idx = state.selected_idx - 1
        M._highlight_selected()
      end
    end
  end, kopts)

  vim.keymap.set({ "i", "n" }, "<CR>", function()
    if state.mode == "ai" then
      local query = get_current_query()
      if state.ai_showing_history and query == "" then
        local item = state.ai_history_results[state.selected_idx]
        if item then
          state.ai_showing_history = false
          state.ai_response = item.response
          local ai = require("tutor-again.ai")
          local is_zh = get_lang() == "zh-TW"
          local header = (is_zh and "Q: " or "Q: ") .. item.question
          local wrapped = ai.wrap_text(item.response, 64)
          local display = { "  " .. header, "" }
          for _, line in ipairs(wrapped) do
            table.insert(display, "  " .. line)
          end
          set_results_lines(display)
        end
      else
        send_ai_query()
      end
    else
      on_select()
    end
  end, kopts)

  vim.keymap.set({ "i", "n" }, "<Tab>", function()
    toggle_lang()
    update_input_title()
    if state.mode == "search" then
      render_results(get_current_query())
    elseif state.ai_response == "" then
      render_ai_history()
    end
  end, kopts)

  -- Copy AI response or error to clipboard
  vim.keymap.set({ "i", "n" }, "<C-y>", function()
    if state.mode == "ai" and state.results_buf and vim.api.nvim_buf_is_valid(state.results_buf) then
      local lines = vim.api.nvim_buf_get_lines(state.results_buf, 0, -1, false)
      -- Strip leading 2-space indent
      local cleaned = {}
      for _, line in ipairs(lines) do
        table.insert(cleaned, (line:gsub("^  ", "")))
      end
      local text = table.concat(cleaned, "\n")
      vim.fn.setreg("+", text)
      local msg = get_lang() == "zh-TW" and "已複製到剪貼簿" or "Copied to clipboard"
      vim.notify(msg, vim.log.levels.INFO)
    end
  end, kopts)

  vim.keymap.set({ "i", "n" }, "<BS>", function()
    if state.mode == "ai" and not state.ai_showing_history and get_current_query() == "" then
      state.ai_response = ""
      render_ai_history()
      return
    end
    -- Default backspace behavior
    local key = vim.api.nvim_replace_termcodes("<BS>", true, false, true)
    vim.api.nvim_feedkeys(key, "n", false)
  end, kopts)

  vim.keymap.set({ "i", "n" }, "<C-d>", function()
    if state.mode == "ai" and state.ai_showing_history then
      local item = state.ai_history_results[state.selected_idx]
      if item then
        ai_history.delete(item.id)
        render_ai_history()
      end
    end
  end, kopts)

  -- Mode toggle
  local config = require("tutor-again").config
  local mode_key = config.ai and config.ai.mode_key or "<C-a>"
  vim.keymap.set({ "i", "n" }, mode_key, toggle_mode, kopts)

  -- Live search on text change (only in search mode)
  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = state.input_buf,
    callback = function()
      if state.mode == "search" then
        render_results(get_current_query())
      end
    end,
  })

  -- Restore previous query when returning from detail
  if opts.restore and state.mode == "search" then
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

  local is_zh = get_lang() == "zh-TW"
  local confirm_msg = is_zh
    and string.format("確定要安裝 %s 嗎？這會寫入你的 Neovim 設定檔。", entry.keys)
    or string.format("Install %s? This will write to your Neovim config.", entry.keys)
  local choice = vim.fn.confirm(confirm_msg, is_zh and "&確定\n&取消" or "&Yes\n&No", 2)
  if choice ~= 1 then return end

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
        local msg = is_zh and "lazy.nvim 已在 init.lua 中設定" or "lazy.nvim already configured in init.lua"
        vim.notify(msg, vim.log.levels.WARN)
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
      vim.notify(is_zh and "正在下載 lazy.nvim..." or "Downloading lazy.nvim...", vim.log.levels.INFO)
      local result = vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", lazypath,
      })
      if vim.v.shell_error ~= 0 then
        local msg = is_zh and ("下載 lazy.nvim 失敗:\n" .. result) or ("Failed to clone lazy.nvim:\n" .. result)
        vim.notify(msg, vim.log.levels.ERROR)
        return
      end
      vim.notify(
        is_zh
          and ("lazy.nvim 安裝完成！\n" .. init_path .. "\n\n請重啟 Neovim 以啟用。")
          or ("lazy.nvim installed!\n" .. init_path .. "\n\nRestart Neovim to activate."),
        vim.log.levels.INFO
      )
    else
      vim.notify(
        is_zh
          and ("lazy.nvim 已下載。設定已寫入:\n" .. init_path)
          or ("lazy.nvim already downloaded. Config written to:\n" .. init_path),
        vim.log.levels.INFO
      )
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
    local msg = is_zh and ("已安裝: " .. filepath) or ("Already installed: " .. filepath)
    vim.notify(msg, vim.log.levels.WARN)
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
    local lazy_loaded = pcall(require, "lazy")
    if lazy_loaded then
      local msg = is_zh
        and ("安裝完成！" .. filepath .. "\n正在執行 :Lazy sync ...")
        or ("Installed! " .. filepath .. "\nRunning :Lazy sync ...")
      vim.notify(msg, vim.log.levels.INFO)
      vim.schedule(function()
        vim.cmd("Lazy sync")
      end)
    else
      local msg = is_zh
        and ("安裝完成！" .. filepath .. "\n請重啟 Neovim 後執行 :Lazy sync")
        or ("Installed! " .. filepath .. "\nRestart Neovim, then run :Lazy sync")
      vim.notify(msg, vim.log.levels.INFO)
    end
  else
    local msg = is_zh
      and ("安裝完成！" .. filepath .. "\n\n未偵測到 lazy.nvim。\n請先安裝 lazy.nvim（搜尋 'lazy.nvim' 後按 I）。")
      or ("Installed! " .. filepath .. "\n\nlazy.nvim not found in init.lua.\nInstall lazy.nvim first (search 'lazy.nvim' and press I).")
    vim.notify(msg, vim.log.levels.WARN)
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
    table.insert(lines, (is_zh and "  助記: " or "  Mnemonic: ") .. entry.mnemonic)
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
    table.insert(lines, is_zh and "  安裝 (lazy.nvim):" or "  Install (lazy.nvim):")
    table.insert(lines, "  " .. string.rep("─", 30))
    for install_line in entry.install:gmatch("[^\n]+") do
      table.insert(lines, "  " .. install_line)
    end
    table.insert(lines, "  " .. string.rep("─", 30))
    table.insert(lines, "")
  end
  if entry.related and #entry.related > 0 then
    table.insert(lines, is_zh and "  相關指令:" or "  Related:")
    for _, r in ipairs(entry.related) do
      table.insert(lines, "    • " .. r)
    end
  end
  table.insert(lines, "")
  table.insert(lines, (is_zh and "  分類: " or "  Category: ") .. (entry.category or ""))
  table.insert(lines, "")
  local hint
  if is_zh then
    hint = "  [q] 關閉  [y] 複製按鍵  [?] 返回  [Tab] 切換語言"
    if entry.install then
      hint = "  [I] 安裝  [Y] 複製設定  [y] 複製按鍵  [?] 返回  [Tab] 切換語言"
    end
  else
    hint = "  [q] close  [y] copy keys  [?] back  [Tab] lang"
    if entry.install then
      hint = "  [I] install  [Y] copy config  [y] copy keys  [?] back  [Tab] lang"
    end
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
    title = string.format(is_zh and " 詳細 [%s] " or " Detail [%s] ", lang_label()),
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
    local msg = get_lang() == "zh-TW" and ("已複製: " .. entry.keys) or ("Copied: " .. entry.keys)
    vim.notify(msg, vim.log.levels.INFO)
    vim.api.nvim_win_close(win, true)
    M.open({ restore = true })
  end, opts)

  if entry.install then
    vim.keymap.set("n", "Y", function()
      vim.fn.setreg("+", entry.install)
      local msg = get_lang() == "zh-TW" and "已複製安裝設定！" or "Copied install config!"
      vim.notify(msg, vim.log.levels.INFO)
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
  local msg = get_lang() == "zh-TW" and "tutor-again: 分類功能即將推出" or "tutor-again: categories coming soon"
  vim.notify(msg, vim.log.levels.INFO)
end

return M
