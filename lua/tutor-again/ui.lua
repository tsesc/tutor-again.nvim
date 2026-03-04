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
}

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
      local display = string.format("  %-8s %s", entry.keys, entry.name_zh or entry.name)
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
  end
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
    history.add(vim.fn.trim(vim.api.nvim_buf_get_lines(state.input_buf, 0, 1, false)[1] or ""))
    close()
    M.open_detail(item.entry)
  end
end

function M.open()
  close()

  local width = 60
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
    title = " tutor-again [Local] ",
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

  -- Live search on text change
  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = state.input_buf,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, 1, false)
      local query = vim.fn.trim(lines[1] or "")
      render_results(query)
    end,
  })

  vim.cmd("startinsert")
end

function M.open_detail(entry)
  local width = 55
  local lines = {}

  table.insert(lines, string.format("  %s — %s", entry.keys, entry.name_zh or entry.name))
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
  if entry.related and #entry.related > 0 then
    table.insert(lines, "  Related:")
    for _, r in ipairs(entry.related) do
      table.insert(lines, "    • " .. r)
    end
  end
  table.insert(lines, "")
  table.insert(lines, "  Category: " .. (entry.category or ""))
  table.insert(lines, "")
  table.insert(lines, "  [q] close  [y] copy keys  [?] back to search")

  local height = #lines
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
    title = " Detail ",
    title_pos = "center",
    style = "minimal",
  })

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
  end, opts)

  vim.keymap.set("n", "?", function()
    vim.api.nvim_win_close(win, true)
    M.open()
  end, opts)
end

function M.open_history()
  M.open()
end

function M.open_categories()
  vim.notify("tutor-again: categories coming soon", vim.log.levels.INFO)
end

return M
