local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T = new_set()

T["history"] = new_set()

T["history"]["add and get entries"] = function()
  local history = require("tutor-again.history")
  history._set_path(vim.fn.tempname())
  history._entries = {}

  history.add("刪除整行")
  history.add("跳到檔案開頭")

  local entries = history.get_all()
  eq(#entries, 2)
  eq(entries[1].query, "跳到檔案開頭") -- most recent first
  eq(entries[2].query, "刪除整行")
end

T["history"]["respects max entries"] = function()
  local history = require("tutor-again.history")
  history._set_path(vim.fn.tempname())
  history._entries = {}

  for i = 1, 10 do
    history.add("query " .. i)
  end

  history._max = 5
  history.add("query 11")

  local entries = history.get_all()
  eq(#entries, 5)
  eq(entries[1].query, "query 11")
end

T["history"]["deduplicates"] = function()
  local history = require("tutor-again.history")
  history._set_path(vim.fn.tempname())
  history._entries = {}

  history.add("same query")
  history.add("other query")
  history.add("same query")

  local entries = history.get_all()
  eq(#entries, 2)
  eq(entries[1].query, "same query") -- moved to top
end

T["history"]["clear empties entries and deletes file"] = function()
  local history = require("tutor-again.history")
  local path = vim.fn.tempname()
  history._set_path(path)
  history._entries = {}

  history.add("test query")
  -- Force write to disk so file exists
  history._write_to_disk()
  eq(vim.fn.filereadable(path), 1)

  history.clear()
  eq(#history._entries, 0)
  eq(vim.fn.filereadable(path), 0)
end

T["history"]["migration moves file from data to state path"] = function()
  local history = require("tutor-again.history")

  -- Create a temp directory structure simulating old data path
  local tmp_base = vim.fn.tempname()
  local old_dir = tmp_base .. "/data/tutor-again"
  local new_dir = tmp_base .. "/state/tutor-again"
  local old_path = old_dir .. "/history.json"
  local new_path = new_dir .. "/history.json"

  vim.fn.mkdir(old_dir, "p")
  vim.fn.writefile({ vim.fn.json_encode({ { query = "migrated", time = 1000 } }) }, old_path)

  -- Stub stdpath to use our temp dirs
  local orig_stdpath = vim.fn.stdpath
  vim.fn.stdpath = function(what)
    if what == "state" then return tmp_base .. "/state" end
    if what == "data" then return tmp_base .. "/data" end
    return orig_stdpath(what)
  end

  -- Reset path so _get_path() re-evaluates
  history._path = nil
  -- Stub config to use default path
  local ta = require("tutor-again")
  local orig_config = ta.config
  ta.config = { history = { path = new_path } }

  local got_path = history._get_path()
  eq(got_path, new_path)
  eq(vim.fn.filereadable(new_path), 1)
  eq(vim.fn.filereadable(old_path), 0)

  -- Verify content was preserved
  history._entries = {}
  history.load()
  eq(#history._entries, 1)
  eq(history._entries[1].query, "migrated")

  -- Restore
  vim.fn.stdpath = orig_stdpath
  ta.config = orig_config
  history._path = nil
  vim.fn.delete(tmp_base, "rf")
end

T["history"]["debounce coalesces multiple saves"] = function()
  local history = require("tutor-again.history")
  local path = vim.fn.tempname()
  history._set_path(path)
  history._entries = { { query = "data", time = 1000 } }

  local write_count = 0
  local orig_write = history._write_to_disk
  history._write_to_disk = function()
    write_count = write_count + 1
    orig_write()
  end

  -- Call save 3 times rapidly
  history.save()
  history.save()
  history.save()

  -- Timer should be pending
  assert(history._save_timer ~= nil, "timer should be pending")

  -- Wait for debounce to fire (1s + buffer)
  vim.wait(1500, function() return history._save_timer == nil end, 50)

  eq(write_count, 1)
  eq(vim.fn.filereadable(path), 1)

  -- Restore
  history._write_to_disk = orig_write
end

T["history"]["merge preserves other instance records"] = function()
  local history = require("tutor-again.history")
  local path = vim.fn.tempname()
  history._set_path(path)
  history._entries = {}

  -- Simulate instance A wrote entries to disk
  local disk_entries = {
    { query = "from instance A", time = 1000 },
    { query = "also from A", time = 900 },
  }
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ vim.fn.json_encode(disk_entries) }, path)

  -- Current instance (B) adds a new query
  history.add("from instance B")

  local entries = history.get_all()
  eq(entries[1].query, "from instance B")

  -- Verify disk entries are preserved
  local found_a1, found_a2 = false, false
  for _, e in ipairs(entries) do
    if e.query == "from instance A" then found_a1 = true end
    if e.query == "also from A" then found_a2 = true end
  end
  assert(found_a1, "should preserve 'from instance A'")
  assert(found_a2, "should preserve 'also from A'")
  eq(#entries, 3)
end

T["format_time"] = new_set()

T["format_time"]["english format"] = function()
  local history = require("tutor-again.history")
  local now = os.time()
  assert(history.format_time(now - 30, "en"):find("s ago"), "should show seconds ago")
  assert(history.format_time(now - 120, "en"):find("m ago"), "should show minutes ago")
  assert(history.format_time(now - 7200, "en"):find("h ago"), "should show hours ago")
  assert(history.format_time(now - 172800, "en"):find("d ago"), "should show days ago")
end

T["format_time"]["zh-TW format"] = function()
  local history = require("tutor-again.history")
  local now = os.time()
  assert(history.format_time(now - 30, "zh-TW"):find("秒前"), "should show 秒前")
  assert(history.format_time(now - 120, "zh-TW"):find("分鐘前"), "should show 分鐘前")
  assert(history.format_time(now - 7200, "zh-TW"):find("小時前"), "should show 小時前")
  assert(history.format_time(now - 172800, "zh-TW"):find("天前"), "should show 天前")
end

T["format_time"]["defaults to english without lang"] = function()
  local history = require("tutor-again.history")
  local now = os.time()
  assert(history.format_time(now - 30):find("s ago"), "should default to English")
end

return T
