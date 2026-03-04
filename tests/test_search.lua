local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T = new_set()

T["score"] = new_set()

T["score"]["returns 0 for no match"] = function()
  local search = require("tutor-again.search")
  eq(search.score("xyz", "abcdef"), 0)
end

T["score"]["returns positive for subsequence match"] = function()
  local search = require("tutor-again.search")
  assert(search.score("dw", "delete word") > 0)
end

T["score"]["is case insensitive"] = function()
  local search = require("tutor-again.search")
  assert(search.score("DW", "delete word") > 0)
end

T["score"]["bonuses consecutive chars"] = function()
  local search = require("tutor-again.search")
  local consecutive = search.score("del", "delete word")
  local scattered = search.score("dew", "delete word")
  assert(consecutive > scattered)
end

T["filter_entries"] = new_set()

T["filter_entries"]["matches against tags and names"] = function()
  local search = require("tutor-again.search")
  local entries = {
    { keys = "dd", name = "Delete line", name_zh = "刪除整行", tags = { "delete", "line", "刪除", "行" } },
    { keys = "w", name = "Next word", name_zh = "下一個字", tags = { "word", "next", "字" } },
  }
  local results = search.filter_entries("刪除", entries)
  eq(#results, 1)
  eq(results[1].keys, "dd")
end

T["filter_entries"]["returns all for empty query"] = function()
  local search = require("tutor-again.search")
  local entries = {
    { keys = "h", name = "Left", name_zh = "左", tags = { "left" } },
    { keys = "l", name = "Right", name_zh = "右", tags = { "right" } },
  }
  local results = search.filter_entries("", entries)
  eq(#results, 2)
end

return T
