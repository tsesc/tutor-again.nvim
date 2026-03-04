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
      if m.lhs == "?" then return true end
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

return T
