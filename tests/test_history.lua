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

return T
