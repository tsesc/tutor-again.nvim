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
