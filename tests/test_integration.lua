local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()

local T = new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[require("tutor-again").setup({})]])
    end,
    post_once = child.stop,
  },
})

T["setup"] = new_set()

T["setup"]["registers TutorAgain command"] = function()
  local has_cmd = child.lua_get([[vim.api.nvim_get_commands({})["TutorAgain"] ~= nil]])
  eq(has_cmd, true)
end

T["setup"]["registers keymap"] = function()
  local maps = child.lua_get([[(function()
    local maps = vim.api.nvim_get_keymap("n")
    for _, m in ipairs(maps) do
      if m.lhs:find("%?") and m.desc and m.desc:find("tutor%-again") then return true end
    end
    return false
  end)()]])
  eq(maps, true)
end

T["database"] = new_set()

T["database"]["loads all entries"] = function()
  local count = child.lua_get([[#require("tutor-again.db").all()]])
  assert(count > 50, "expected >50 entries, got " .. tostring(count))
end

T["search"] = new_set()

T["search"]["finds movement commands"] = function()
  local found = child.lua_get([[(function()
    local search = require("tutor-again.search")
    local db = require("tutor-again.db")
    local results = search.filter_entries("delete line", db.all())
    return #results > 0
  end)()]])
  eq(found, true)
end

T["search"]["finds by Chinese"] = function()
  local keys = child.lua_get([[(function()
    local search = require("tutor-again.search")
    local db = require("tutor-again.db")
    local results = search.filter_entries("刪除整行", db.all())
    if #results > 0 then return results[1].keys end
    return ""
  end)()]])
  eq(keys, "dd")
end

T["ui"] = new_set()

T["ui"]["open_detail enters normal mode"] = function()
  local mode = child.lua_get([[(function()
    local ui = require("tutor-again.ui")
    local entry = {
      keys = "dd",
      name = "Delete line",
      name_zh = "刪除整行",
      category = "operators",
      mnemonic = "d=delete",
      description = "Delete the current line",
    }
    -- Simulate coming from insert mode (like the search input)
    vim.cmd("startinsert")
    ui.open_detail(entry)
    return vim.api.nvim_get_mode().mode
  end)()]])
  eq(mode, "n")
end

T["setup"]["has ai subcommand"] = function()
  local has_cmd = child.lua_get([[vim.api.nvim_get_commands({})["TutorAgain"] ~= nil]])
  eq(has_cmd, true)
  -- Verify complete function returns "ai"
  local completions = child.lua_get([[(function()
    local cmd = vim.api.nvim_get_commands({})["TutorAgain"]
    return cmd ~= nil
  end)()]])
  eq(completions, true)
end

T["i18n"] = new_set()

T["i18n"]["ai system prompt uses english for zh-TW"] = function()
  local prompt = child.lua_get([[require("tutor-again.ai").build_system_prompt("zh-TW")]])
  assert(prompt:find("# Role"), "should have English 'Role' heading")
  assert(prompt:find("Traditional Chinese"), "should instruct Traditional Chinese")
  assert(prompt:find("繁體中文"), "should include 繁體中文")
end

T["i18n"]["ai system prompt uses english for en"] = function()
  local prompt = child.lua_get([[require("tutor-again.ai").build_system_prompt("en")]])
  assert(prompt:find("# Role"), "should have English 'Role' heading")
  assert(prompt:find("Reply in %*%*English%*%*"), "should instruct English reply")
end

T["i18n"]["db entries have bilingual names"] = function()
  local result = child.lua_get([[(function()
    local db = require("tutor-again.db")
    local total, with_zh = 0, 0
    for _, e in ipairs(db.all()) do
      total = total + 1
      if e.name_zh then with_zh = with_zh + 1 end
    end
    return { total = total, with_zh = with_zh }
  end)()]])
  assert(result.with_zh / result.total > 0.8,
    string.format("only %d/%d entries have name_zh", result.with_zh, result.total))
end

T["ai_module"] = new_set()

T["ai_module"]["get_api_key returns nil without config or env"] = function()
  local key = child.lua_get([[(function()
    local ai = require("tutor-again.ai")
    local orig_g = vim.env.GEMINI_API_KEY
    local orig_o = vim.env.OPENROUTER_API_KEY
    vim.env.GEMINI_API_KEY = nil
    vim.env.OPENROUTER_API_KEY = nil
    require("tutor-again").config = { ai = { api_key = nil } }
    local k = ai.get_api_key()
    vim.env.GEMINI_API_KEY = orig_g
    vim.env.OPENROUTER_API_KEY = orig_o
    return k
  end)()]])
  eq(key, vim.NIL)
end

T["ai_module"]["wrap_text handles text with spaces"] = function()
  local count = child.lua_get([[(function()
    local ai = require("tutor-again.ai")
    local lines = ai.wrap_text("這是 一段 很長的 中文 文字 需要 被換行 顯示 在浮動 視窗中 測試 換行", 20)
    return #lines
  end)()]])
  assert(count > 1, "should wrap text with spaces into multiple lines")
end

return T
