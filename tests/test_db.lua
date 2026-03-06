local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T = new_set()

T["all"] = new_set()

T["all"]["returns non-empty list"] = function()
  local db = require("tutor-again.db")
  local entries = db.all()
  assert(#entries > 50, "expected >50 entries, got " .. #entries)
end

T["all"]["every entry has required fields"] = function()
  local db = require("tutor-again.db")
  for _, entry in ipairs(db.all()) do
    assert(entry.keys, "missing keys field")
    assert(entry.name, "missing name field: " .. (entry.keys or "?"))
    assert(entry.category, "missing category field: " .. entry.keys)
  end
end

T["all"]["every entry has tags table"] = function()
  local db = require("tutor-again.db")
  for _, entry in ipairs(db.all()) do
    assert(type(entry.tags) == "table", "tags must be table for: " .. entry.keys)
    assert(#entry.tags > 0, "tags must not be empty for: " .. entry.keys)
  end
end

T["all"]["most entries have name_zh for i18n"] = function()
  local db = require("tutor-again.db")
  local total = 0
  local with_zh = 0
  for _, entry in ipairs(db.all()) do
    total = total + 1
    if entry.name_zh then with_zh = with_zh + 1 end
  end
  -- At least 80% should have zh name
  local ratio = with_zh / total
  assert(ratio > 0.8, string.format("only %.0f%% entries have name_zh (%d/%d)", ratio * 100, with_zh, total))
end

T["all"]["categories are valid"] = function()
  local db = require("tutor-again.db")
  local valid_tops = {
    movement = true, operators = true, text_objects = true,
    insert = true, visual = true, search = true,
    files = true, settings = true, plugins = true,
  }
  for _, entry in ipairs(db.all()) do
    local top = entry.category:match("^([^.]+)")
    assert(valid_tops[top], "invalid category: " .. entry.category .. " for " .. entry.keys)
  end
end

T["all"]["no duplicate keys within same category"] = function()
  local db = require("tutor-again.db")
  local seen = {}
  for _, entry in ipairs(db.all()) do
    local key = entry.category .. ":" .. entry.keys
    assert(not seen[key], "duplicate: " .. key)
    seen[key] = true
  end
end

T["reload"] = new_set()

T["reload"]["returns fresh entries"] = function()
  local db = require("tutor-again.db")
  local a = db.all()
  local b = db.reload()
  eq(#a, #b)
end

return T
