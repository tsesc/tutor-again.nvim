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
  eq(entries[1].question, "How to jump?")
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
  eq(entries[1].question, "q7")
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
