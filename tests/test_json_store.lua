local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T = new_set()

T["json_store"] = new_set()

T["json_store"]["create returns store with expected fields"] = function()
  local json_store = require("tutor-again.json_store")
  local s = json_store.create({ filename = "test.json", max = 10, dedup_key = "key" })

  eq(type(s._entries), "table")
  eq(#s._entries, 0)
  eq(s._max, 10)
  eq(type(s.load), "function")
  eq(type(s.save), "function")
  eq(type(s.clear), "function")
  eq(type(s.get_all), "function")
  eq(type(s._write_to_disk), "function")
  eq(type(s._merge_disk), "function")
  eq(type(s._set_path), "function")
  eq(type(s._get_path), "function")
end

T["json_store"]["create uses default max of 500"] = function()
  local json_store = require("tutor-again.json_store")
  local s = json_store.create({ filename = "test.json", dedup_key = "key" })
  eq(s._max, 500)
end

T["json_store"]["load and write roundtrip"] = function()
  local json_store = require("tutor-again.json_store")
  local s = json_store.create({ filename = "test.json", max = 100, dedup_key = "key" })
  local path = vim.fn.tempname()
  s._set_path(path)

  s._entries = {
    { key = "a", value = 1 },
    { key = "b", value = 2 },
  }
  s._write_to_disk()

  -- Create a fresh store and load
  local s2 = json_store.create({ filename = "test.json", max = 100, dedup_key = "key" })
  s2._set_path(path)
  s2.load()

  eq(#s2._entries, 2)
  eq(s2._entries[1].key, "a")
  eq(s2._entries[2].key, "b")
end

T["json_store"]["load handles missing file"] = function()
  local json_store = require("tutor-again.json_store")
  local s = json_store.create({ filename = "test.json", max = 100, dedup_key = "key" })
  s._set_path(vim.fn.tempname())
  s.load()
  eq(#s._entries, 0)
end

T["json_store"]["load handles corrupt json"] = function()
  local json_store = require("tutor-again.json_store")
  local s = json_store.create({ filename = "test.json", max = 100, dedup_key = "key" })
  local path = vim.fn.tempname()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ "not valid json {{{" }, path)

  s._set_path(path)
  s.load()
  eq(#s._entries, 0)
end

T["json_store"]["load handles empty file"] = function()
  local json_store = require("tutor-again.json_store")
  local s = json_store.create({ filename = "test.json", max = 100, dedup_key = "key" })
  local path = vim.fn.tempname()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({}, path)

  s._set_path(path)
  s.load()
  eq(#s._entries, 0)
end

T["json_store"]["clear empties entries and deletes file"] = function()
  local json_store = require("tutor-again.json_store")
  local s = json_store.create({ filename = "test.json", max = 100, dedup_key = "key" })
  local path = vim.fn.tempname()
  s._set_path(path)

  s._entries = { { key = "a" } }
  s._write_to_disk()
  eq(vim.fn.filereadable(path), 1)

  s.clear()
  eq(#s._entries, 0)
  eq(vim.fn.filereadable(path), 0)
end

T["json_store"]["get_all lazy loads"] = function()
  local json_store = require("tutor-again.json_store")
  local s = json_store.create({ filename = "test.json", max = 100, dedup_key = "key" })
  local path = vim.fn.tempname()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ vim.fn.json_encode({ { key = "loaded" } }) }, path)

  s._set_path(path)
  local entries = s.get_all()
  eq(#entries, 1)
  eq(entries[1].key, "loaded")
end

T["json_store"]["merge_disk deduplicates by dedup_key"] = function()
  local json_store = require("tutor-again.json_store")
  local s = json_store.create({ filename = "test.json", max = 100, dedup_key = "key" })
  local path = vim.fn.tempname()
  s._set_path(path)

  -- Write disk entries
  local disk_entries = {
    { key = "a", source = "disk" },
    { key = "b", source = "disk" },
    { key = "c", source = "disk" },
  }
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ vim.fn.json_encode(disk_entries) }, path)

  -- Memory already has "a" and "d"
  s._entries = {
    { key = "a", source = "memory" },
    { key = "d", source = "memory" },
  }

  s._merge_disk()

  eq(#s._entries, 4) -- a(memory), d(memory), b(disk), c(disk)
  -- "a" should be from memory (not duplicated)
  eq(s._entries[1].source, "memory")
  eq(s._entries[1].key, "a")
end

T["json_store"]["debounce coalesces multiple saves"] = function()
  local json_store = require("tutor-again.json_store")
  local s = json_store.create({ filename = "test.json", max = 100, dedup_key = "key" })
  local path = vim.fn.tempname()
  s._set_path(path)
  s._entries = { { key = "data" } }

  local write_count = 0
  local orig_write = s._write_to_disk
  s._write_to_disk = function()
    write_count = write_count + 1
    orig_write()
  end

  s.save()
  s.save()
  s.save()

  assert(s._save_timer ~= nil, "timer should be pending")
  vim.wait(1500, function() return s._save_timer == nil end, 50)

  eq(write_count, 1)
  eq(vim.fn.filereadable(path), 1)

  s._write_to_disk = orig_write
end

T["json_store"]["each create returns independent instance"] = function()
  local json_store = require("tutor-again.json_store")
  local s1 = json_store.create({ filename = "a.json", max = 10, dedup_key = "id" })
  local s2 = json_store.create({ filename = "b.json", max = 20, dedup_key = "key" })

  s1._entries = { { id = 1 } }
  eq(#s2._entries, 0)
  eq(s1._max, 10)
  eq(s2._max, 20)
end

return T
