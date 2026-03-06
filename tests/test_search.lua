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

T["best_score"] = new_set()

T["best_score"]["matches keys field"] = function()
  local search = require("tutor-again.search")
  local entry = { keys = "dd", name = "Delete line", tags = { "delete" }, category = "operators" }
  assert(search.best_score("dd", entry) > 0)
end

T["best_score"]["matches name_zh"] = function()
  local search = require("tutor-again.search")
  local entry = { keys = "dd", name = "Delete line", name_zh = "刪除整行", tags = { "delete" }, category = "operators" }
  assert(search.best_score("刪除", entry) > 0)
end

T["best_score"]["matches description"] = function()
  local search = require("tutor-again.search")
  local entry = { keys = "dd", name = "Delete line", description = "Delete the current line", tags = {}, category = "operators" }
  assert(search.best_score("current", entry) > 0)
end

T["best_score"]["matches category aliases"] = function()
  local search = require("tutor-again.search")
  local entry = { keys = "h", name = "Left", tags = { "left" }, category = "movement" }
  assert(search.best_score("navigate", entry) > 0, "should match 'navigate' alias for movement")
  assert(search.best_score("移動", entry) > 0, "should match '移動' alias for movement")
end

T["best_score"]["returns 0 for unmatched"] = function()
  local search = require("tutor-again.search")
  local entry = { keys = "dd", name = "Delete line", tags = { "delete" }, category = "operators" }
  eq(search.best_score("zzzzz", entry), 0)
end

return T
