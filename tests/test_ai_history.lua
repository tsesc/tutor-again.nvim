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

  eq(#ai_history._entries, 0)
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

return T
