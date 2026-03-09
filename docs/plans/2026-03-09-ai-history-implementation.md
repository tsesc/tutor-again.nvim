# AI Conversation History Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Save AI conversations to local JSON file and display them in AI mode when input is empty, mirroring how search history works in search mode.

**Architecture:** New `ai_history.lua` module (mirrors `history.lua` patterns: lazy load, debounced write, atomic save, multi-instance merge). UI changes in `ui.lua` to show AI history list in AI mode when input is empty, handle selection/deletion, and auto-save after AI responses complete.

**Tech Stack:** Lua (Neovim plugin), MiniTest, JSON file storage at `~/.local/state/nvim/tutor-again/ai_history.json`

---

### Task 1: Add config default for `ai.history_max_entries`

**Files:**
- Modify: `lua/tutor-again/config.lua:10-17`
- Test: `tests/test_config.lua`

**Step 1: Write the failing test**

Add to `tests/test_config.lua`:

```lua
T["config"]["ai history_max_entries default"] = function()
  local config = require("tutor-again.config")
  local result = config.build({})
  eq(result.ai.history_max_entries, 100)
end

T["config"]["ai history_max_entries override"] = function()
  local config = require("tutor-again.config")
  local result = config.build({ ai = { history_max_entries = 50 } })
  eq(result.ai.history_max_entries, 50)
end

T["config"]["ai history_max_entries zero disables"] = function()
  local config = require("tutor-again.config")
  local result = config.build({ ai = { history_max_entries = 0 } })
  eq(result.ai.history_max_entries, 0)
end
```

**Step 2: Run tests to verify they fail**

Run: `make test-unit`
Expected: FAIL — `result.ai.history_max_entries` is `nil`

**Step 3: Write minimal implementation**

In `lua/tutor-again/config.lua`, add `history_max_entries = 100` to the `ai` table in `M.defaults`:

```lua
ai = {
  enabled = true,
  api_key = nil,
  base_url = "https://generativelanguage.googleapis.com/v1beta/openai",
  model = "gemini-2.5-flash-lite",
  mode_key = "<C-a>",
  include_config = false,
  history_max_entries = 100,
},
```

**Step 4: Run tests to verify they pass**

Run: `make test-unit`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lua/tutor-again/config.lua tests/test_config.lua
git commit -m "feat: Add ai.history_max_entries config default"
```

---

### Task 2: Create `ai_history.lua` — core data operations (add, get_all, delete)

**Files:**
- Create: `lua/tutor-again/ai_history.lua`
- Create: `tests/test_ai_history.lua`

**Step 1: Write the failing tests**

Create `tests/test_ai_history.lua`:

```lua
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T = new_set()

T["ai_history"] = new_set()

T["ai_history"]["add and get entries"] = function()
  local ai_history = require("tutor-again.ai_history")
  ai_history._set_path(vim.fn.tempname())
  ai_history._entries = {}

  ai_history.add("怎麼刪除一行？", "用 dd 可以刪除整行", "zh-TW")
  ai_history.add("How to jump?", "Use gg to jump to top", "en")

  local entries = ai_history.get_all()
  eq(#entries, 2)
  eq(entries[1].question, "How to jump?") -- most recent first
  eq(entries[1].response, "Use gg to jump to top")
  eq(entries[1].lang, "en")
  eq(entries[2].question, "怎麼刪除一行？")
  assert(entries[1].timestamp ~= nil, "should have timestamp")
  assert(entries[1].id ~= nil, "should have id")
end

T["ai_history"]["ignores empty question or response"] = function()
  local ai_history = require("tutor-again.ai_history")
  ai_history._set_path(vim.fn.tempname())
  ai_history._entries = {}

  ai_history.add("", "some response", "en")
  ai_history.add("some question", "", "en")
  ai_history.add(nil, "response", "en")
  ai_history.add("question", nil, "en")

  eq(#ai_history.get_all(), 0)
end

T["ai_history"]["respects max entries"] = function()
  local ai_history = require("tutor-again.ai_history")
  ai_history._set_path(vim.fn.tempname())
  ai_history._entries = {}
  ai_history._max = 5

  for i = 1, 7 do
    ai_history.add("q" .. i, "r" .. i, "en")
  end

  local entries = ai_history.get_all()
  eq(#entries, 5)
  eq(entries[1].question, "q7") -- most recent
end

T["ai_history"]["delete removes entry by id"] = function()
  local ai_history = require("tutor-again.ai_history")
  ai_history._set_path(vim.fn.tempname())
  ai_history._entries = {}

  ai_history.add("q1", "r1", "en")
  ai_history.add("q2", "r2", "en")

  local entries = ai_history.get_all()
  local id_to_delete = entries[1].id
  ai_history.delete(id_to_delete)

  entries = ai_history.get_all()
  eq(#entries, 1)
  eq(entries[1].question, "q1")
end

T["ai_history"]["clear empties entries and deletes file"] = function()
  local ai_history = require("tutor-again.ai_history")
  local path = vim.fn.tempname()
  ai_history._set_path(path)
  ai_history._entries = {}

  ai_history.add("test", "response", "en")
  ai_history._write_to_disk()
  eq(vim.fn.filereadable(path), 1)

  ai_history.clear()
  eq(#ai_history._entries, 0)
  eq(vim.fn.filereadable(path), 0)
end

return T
```

**Step 2: Run tests to verify they fail**

Run: `nvim --headless -u scripts/minimal_init.lua -c "lua MiniTest.run_file('tests/test_ai_history.lua')" -c "qall!" 2>&1`
Expected: FAIL — module `tutor-again.ai_history` not found

**Step 3: Write minimal implementation**

Create `lua/tutor-again/ai_history.lua`:

```lua
local M = {}

M._entries = {}
M._path = nil
M._max = 100
M._save_timer = nil

function M._set_path(path)
  M._path = path
end

function M._get_path()
  if M._path then return M._path end
  M._path = vim.fn.stdpath("state") .. "/tutor-again/ai_history.json"
  return M._path
end

function M.load()
  local path = M._get_path()
  if vim.fn.filereadable(path) == 0 then
    M._entries = {}
    return
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or #lines == 0 then
    M._entries = {}
    return
  end
  local raw = table.concat(lines, "\n")
  local ok2, data = pcall(vim.fn.json_decode, raw)
  if ok2 and type(data) == "table" then
    M._entries = data
  else
    M._entries = {}
  end
end

function M._write_to_disk()
  local path = M._get_path()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  local ok, encoded = pcall(vim.fn.json_encode, M._entries)
  if ok then
    local tmp = path .. ".tmp." .. vim.fn.getpid()
    local wok = pcall(vim.fn.writefile, { encoded }, tmp)
    if wok then
      vim.fn.rename(tmp, path)
    end
  end
end

function M.save()
  if M._save_timer then
    M._save_timer:stop()
    M._save_timer = nil
  end
  M._save_timer = vim.defer_fn(function()
    M._save_timer = nil
    M._write_to_disk()
  end, 1000)
end

function M.clear()
  M._entries = {}
  if M._save_timer then
    M._save_timer:stop()
    M._save_timer = nil
  end
  local path = M._get_path()
  if vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
  end
end

function M._merge_disk()
  local path = M._get_path()
  if vim.fn.filereadable(path) == 0 then return end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or #lines == 0 then return end
  local raw = table.concat(lines, "\n")
  local ok2, disk_data = pcall(vim.fn.json_decode, raw)
  if not ok2 or type(disk_data) ~= "table" then return end

  local seen = {}
  for _, entry in ipairs(M._entries) do
    seen[entry.id] = true
  end
  for _, entry in ipairs(disk_data) do
    if not seen[entry.id] then
      table.insert(M._entries, entry)
      seen[entry.id] = true
    end
  end
end

function M.add(question, response, lang)
  if not question or question == "" then return end
  if not response or response == "" then return end

  M._merge_disk()

  local now = os.time()
  table.insert(M._entries, 1, {
    id = now,
    question = question,
    response = response,
    lang = lang or "en",
    timestamp = now,
  })

  -- Trim to max
  local max = M._max
  local ok, ta = pcall(require, "tutor-again")
  if ok and ta.config and ta.config.ai and ta.config.ai.history_max_entries then
    max = ta.config.ai.history_max_entries
  end
  if max == 0 then
    M._entries = {}
    return
  end
  while #M._entries > max do
    table.remove(M._entries)
  end

  M.save()
end

function M.delete(id)
  for i, entry in ipairs(M._entries) do
    if entry.id == id then
      table.remove(M._entries, i)
      M.save()
      return true
    end
  end
  return false
end

function M.get_all()
  if #M._entries == 0 then
    M.load()
  end
  return M._entries
end

return M
```

**Step 4: Run tests to verify they pass**

Run: `nvim --headless -u scripts/minimal_init.lua -c "lua MiniTest.run_file('tests/test_ai_history.lua')" -c "qall!" 2>&1`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lua/tutor-again/ai_history.lua tests/test_ai_history.lua
git commit -m "feat: Add ai_history module with add/get/delete/clear"
```

---

### Task 3: Add persistence tests (debounce, disk read/write, merge, corrupt file)

**Files:**
- Modify: `tests/test_ai_history.lua`

**Step 1: Write the failing tests**

Append to `tests/test_ai_history.lua` (before `return T`):

```lua
T["ai_history"]["load from disk"] = function()
  local ai_history = require("tutor-again.ai_history")
  local path = vim.fn.tempname()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")

  local data = {
    { id = 1000, question = "q1", response = "r1", lang = "en", timestamp = 1000 },
  }
  vim.fn.writefile({ vim.fn.json_encode(data) }, path)

  ai_history._set_path(path)
  ai_history._entries = {}
  ai_history.load()

  eq(#ai_history._entries, 1)
  eq(ai_history._entries[1].question, "q1")
end

T["ai_history"]["handles corrupt json file"] = function()
  local ai_history = require("tutor-again.ai_history")
  local path = vim.fn.tempname()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")

  vim.fn.writefile({ "not valid json {{{" }, path)

  ai_history._set_path(path)
  ai_history._entries = {}
  ai_history.load()

  eq(#ai_history._entries, 0) -- should not crash
end

T["ai_history"]["handles empty file"] = function()
  local ai_history = require("tutor-again.ai_history")
  local path = vim.fn.tempname()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({}, path)

  ai_history._set_path(path)
  ai_history._entries = {}
  ai_history.load()

  eq(#ai_history._entries, 0)
end

T["ai_history"]["debounce coalesces multiple saves"] = function()
  local ai_history = require("tutor-again.ai_history")
  local path = vim.fn.tempname()
  ai_history._set_path(path)
  ai_history._entries = { { id = 1, question = "q", response = "r", lang = "en", timestamp = 1 } }

  local write_count = 0
  local orig_write = ai_history._write_to_disk
  ai_history._write_to_disk = function()
    write_count = write_count + 1
    orig_write()
  end

  ai_history.save()
  ai_history.save()
  ai_history.save()

  assert(ai_history._save_timer ~= nil, "timer should be pending")
  vim.wait(1500, function() return ai_history._save_timer == nil end, 50)

  eq(write_count, 1)
  eq(vim.fn.filereadable(path), 1)

  ai_history._write_to_disk = orig_write
end

T["ai_history"]["merge preserves other instance records"] = function()
  local ai_history = require("tutor-again.ai_history")
  local path = vim.fn.tempname()
  ai_history._set_path(path)
  ai_history._entries = {}

  local disk_entries = {
    { id = 1000, question = "from A", response = "rA", lang = "en", timestamp = 1000 },
    { id = 900, question = "from A2", response = "rA2", lang = "en", timestamp = 900 },
  }
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ vim.fn.json_encode(disk_entries) }, path)

  ai_history.add("from B", "rB", "en")

  local entries = ai_history.get_all()
  eq(entries[1].question, "from B")

  local found_a1, found_a2 = false, false
  for _, e in ipairs(entries) do
    if e.question == "from A" then found_a1 = true end
    if e.question == "from A2" then found_a2 = true end
  end
  assert(found_a1, "should preserve 'from A'")
  assert(found_a2, "should preserve 'from A2'")
  eq(#entries, 3)
end
```

**Step 2: Run tests to verify they pass**

Run: `nvim --headless -u scripts/minimal_init.lua -c "lua MiniTest.run_file('tests/test_ai_history.lua')" -c "qall!" 2>&1`
Expected: ALL PASS (implementation already handles these cases)

**Step 3: Commit**

```bash
git add tests/test_ai_history.lua
git commit -m "test: Add persistence tests for ai_history module"
```

---

### Task 4: Add `test_ai_history.lua` to Makefile test-unit target

**Files:**
- Modify: `Makefile:9-15`

**Step 1: Add the new test file to test-unit**

In `Makefile`, add a new line to the `test-unit` target:

```makefile
test-unit:
	nvim --headless -u scripts/minimal_init.lua \
		-c "lua MiniTest.run_file('tests/test_search.lua')" \
		-c "lua MiniTest.run_file('tests/test_history.lua')" \
		-c "lua MiniTest.run_file('tests/test_ai.lua')" \
		-c "lua MiniTest.run_file('tests/test_ai_history.lua')" \
		-c "lua MiniTest.run_file('tests/test_config.lua')" \
		-c "lua MiniTest.run_file('tests/test_db.lua')" \
		-c "qall!" 2>&1
```

**Step 2: Run full test suite**

Run: `make test-unit`
Expected: ALL PASS

**Step 3: Commit**

```bash
git add Makefile
git commit -m "build: Add test_ai_history.lua to test-unit target"
```

---

### Task 5: Show AI history list when input is empty in AI mode

**Files:**
- Modify: `lua/tutor-again/ui.lua`

This is the core UI change. When in AI mode and input is empty, show AI history instead of the placeholder text. We need to:

1. Add `ai_history` require at the top
2. Add new state fields for AI history browsing
3. Create a `render_ai_history()` function
4. Replace `show_ai_placeholder()` with history when entries exist
5. Update `<Up>`/`<Down>` keys to navigate history list when in AI history view
6. Update `<CR>` to handle history selection

**Step 1: Add `ai_history` require and state fields**

At `lua/tutor-again/ui.lua:5` (after the `history` require), add:

```lua
local ai_history = require("tutor-again.ai_history")
```

In the `state` table (around line 7-20), add these fields:

```lua
ai_showing_history = false,  -- true when displaying AI history list
ai_history_results = {},     -- current AI history entries being shown
```

**Step 2: Create `render_ai_history()` function**

Add this new function after the `show_ai_placeholder()` function (after line 259):

```lua
local function render_ai_history()
  if not state.results_buf or not vim.api.nvim_buf_is_valid(state.results_buf) then return end

  local entries = ai_history.get_all()
  local lines = {}
  state.ai_history_results = {}

  for i, entry in ipairs(entries) do
    if i > 20 then break end
    local time_str = history.format_time(entry.timestamp, get_lang())
    local q = entry.question
    local max_q_len = 40
    if #q > max_q_len then
      q = q:sub(1, max_q_len - 1) .. "…"
    end
    table.insert(lines, string.format("  %s%s%s", q, string.rep(" ", math.max(1, max_q_len + 2 - #q)), time_str))
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
```

**Step 3: Replace `show_ai_placeholder()` calls with `render_ai_history()`**

There are 3 places where `show_ai_placeholder()` is called. Replace as follows:

1. `toggle_mode()` (around line 272): Change `show_ai_placeholder()` to `render_ai_history()`
2. `M.open()` (around line 390): Change `show_ai_placeholder()` to `render_ai_history()`
3. `<Tab>` keymap (around line 449): Change the condition — when `ai_response == ""`, call `render_ai_history()` instead of `show_ai_placeholder()`

**Step 4: Update `<Down>` key handler** (around line 401-418)

Replace the AI mode branch:

```lua
if state.mode == "ai" then
  if state.ai_showing_history then
    -- Navigate history list
    local line_count = vim.api.nvim_buf_line_count(state.results_buf)
    if state.selected_idx < line_count then
      state.selected_idx = state.selected_idx + 1
      M._highlight_selected()
    end
  else
    -- Scroll AI response
    if state.results_win and vim.api.nvim_win_is_valid(state.results_win) then
      local count = vim.api.nvim_buf_line_count(state.results_buf)
      local cursor = vim.api.nvim_win_get_cursor(state.results_win)
      if cursor[1] < count then
        pcall(vim.api.nvim_win_set_cursor, state.results_win, { cursor[1] + 1, 0 })
      end
    end
  end
```

**Step 5: Update `<Up>` key handler** (around line 420-434)

Replace the AI mode branch:

```lua
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
```

**Step 6: Update `<CR>` handler** (around line 436-442)

Replace:

```lua
vim.keymap.set({ "i", "n" }, "<CR>", function()
  if state.mode == "ai" then
    if state.ai_showing_history then
      local item = state.ai_history_results[state.selected_idx]
      if item then
        -- Load history entry into results view
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
```

**Step 7: Reset `ai_showing_history` when sending a query**

In `send_ai_query()` (around line 296), add after `state.ai_response = ""`:

```lua
state.ai_showing_history = false
state.ai_history_results = {}
```

**Step 8: Add `<C-d>` keymap for deleting AI history**

Add after the `<C-y>` keymap block (after line 468):

```lua
vim.keymap.set({ "i", "n" }, "<C-d>", function()
  if state.mode == "ai" and state.ai_showing_history then
    local item = state.ai_history_results[state.selected_idx]
    if item then
      ai_history.delete(item.id)
      render_ai_history()
    end
  end
end, kopts)
```

**Step 9: Run full test suite**

Run: `make test`
Expected: ALL PASS

**Step 10: Commit**

```bash
git add lua/tutor-again/ui.lua
git commit -m "feat: Show AI history list in AI mode when input is empty"
```

---

### Task 6: Auto-save AI response after completion

**Files:**
- Modify: `lua/tutor-again/ui.lua` (the `send_ai_query` function)

**Step 1: Save response in `on_done` callback**

In the `send_ai_query()` function, modify the `on_done` callback (around line 321-323):

From:
```lua
on_done = function()
  state.ai_job_id = nil
end,
```

To:
```lua
on_done = function()
  state.ai_job_id = nil
  -- Save to AI history
  if state.ai_response ~= "" then
    local config = require("tutor-again").config
    local max = config.ai and config.ai.history_max_entries
    if max ~= 0 then
      ai_history.add(query, state.ai_response, get_lang())
    end
  end
end,
```

Note: `query` is already captured in the closure from line 287.

**Step 2: Run full test suite**

Run: `make test`
Expected: ALL PASS

**Step 3: Manual verification**

Run: `make dev`
1. Open tutor-again with `<leader>?`
2. Press `<C-a>` to switch to AI mode — should show empty placeholder (no history yet)
3. Type a question and press Enter — AI responds
4. Close and reopen, press `<C-a>` — should show the question in history
5. Select history entry with Enter — should show full Q&A
6. Press `<C-d>` on a history entry — should delete it

**Step 4: Commit**

```bash
git add lua/tutor-again/ui.lua
git commit -m "feat: Auto-save AI conversations to history"
```

---

### Task 7: Add `clear-ai-history` command and update hints

**Files:**
- Modify: `lua/tutor-again/init.lua`
- Modify: `lua/tutor-again/ui.lua` (hints)

**Step 1: Add command to init.lua**

In `lua/tutor-again/init.lua`, add a new command handler in the `TutorAgain` command function (after the `clear-history` handler):

```lua
elseif arg == "clear-ai-history" then
  require("tutor-again.ai_history").clear()
  vim.notify("tutor-again: AI history cleared", vim.log.levels.INFO)
```

Update the completions list to include `"clear-ai-history"`:

```lua
return { "history", "categories", "ai", "clear-history", "clear-ai-history" }
```

**Step 2: Update AI mode hints in `build_hints()`**

In `lua/tutor-again/ui.lua`, update `build_hints()` to show `C-d` hint when in AI mode:

From:
```lua
if state.mode == "ai" then
  if is_zh then
    return string.format(" %s=搜尋 Tab=語言 C-y=複製 ", mode_key)
  else
    return string.format(" %s=search Tab=lang C-y=copy ", mode_key)
  end
```

To:
```lua
if state.mode == "ai" then
  if is_zh then
    return string.format(" %s=搜尋 Tab=語言 C-y=複製 C-d=刪除 ", mode_key)
  else
    return string.format(" %s=search Tab=lang C-y=copy C-d=del ", mode_key)
  end
```

**Step 3: Run full test suite**

Run: `make test`
Expected: ALL PASS

**Step 4: Commit**

```bash
git add lua/tutor-again/init.lua lua/tutor-again/ui.lua
git commit -m "feat: Add clear-ai-history command and update hints"
```

---

### Task 8: Final integration test and cleanup

**Files:**
- All modified files

**Step 1: Run full test suite**

Run: `make test`
Expected: ALL PASS

**Step 2: Manual end-to-end test**

Run: `make dev`
Verify the full flow:
1. `<leader>?` → opens search mode with search history
2. `<C-a>` → switches to AI mode, shows AI history (or placeholder if empty)
3. Type question + Enter → AI responds and streams
4. Close + reopen → AI history shows the question with timestamp
5. Select history entry → loads full Q&A
6. `<C-d>` on history → deletes entry
7. `<C-y>` on loaded response → copies to clipboard
8. `:TutorAgain clear-ai-history` → clears all AI history
9. Verify `~/.local/state/nvim/tutor-again/ai_history.json` exists and contains data

**Step 3: Run linting check**

Run: `make test` (one final time)
Expected: ALL PASS, no warnings

**Step 4: Commit any remaining cleanup**

If any cleanup was needed:
```bash
git add -A
git commit -m "chore: Final cleanup for AI history feature"
```
