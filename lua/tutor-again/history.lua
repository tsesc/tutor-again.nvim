local store = require("tutor-again.json_store")
local M = store.create({
  filename = "history.json",
  max = 500,
  dedup_key = "query",
})

-- Override _get_path: read config path + migration logic (history-specific)
local _base_get_path = M._get_path
function M._get_path()
  if M._path then return M._path end
  local config = require("tutor-again").config
  if config.history and config.history.path then
    M._path = config.history.path
  else
    M._path = _base_get_path()
  end

  -- Migration: move old data path to new state path
  if vim.fn.filereadable(M._path) == 0 then
    local state_dir = vim.fn.stdpath("state")
    local escaped = state_dir:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
    local old_path = M._path:gsub(escaped, vim.fn.stdpath("data"))
    if old_path ~= M._path and vim.fn.filereadable(old_path) == 1 then
      local dir = vim.fn.fnamemodify(M._path, ":h")
      vim.fn.mkdir(dir, "p")
      vim.fn.rename(old_path, M._path)
      -- Clean up empty old directory
      local old_dir = vim.fn.fnamemodify(old_path, ":h")
      pcall(vim.fn.delete, old_dir, "d")
    end
  end

  return M._path
end

function M.add(query)
  if not query or query == "" then return end

  -- Merge disk entries from other instances into memory
  M._merge_disk()

  -- Remove duplicate
  for i, entry in ipairs(M._entries) do
    if entry.query == query then
      table.remove(M._entries, i)
      break
    end
  end

  -- Add to front
  table.insert(M._entries, 1, {
    query = query,
    time = os.time(),
  })

  -- Trim
  local max = M._max
  local ok, ta = pcall(require, "tutor-again")
  if ok and ta.config and ta.config.history and ta.config.history.max_entries then
    max = ta.config.history.max_entries
  end
  while #M._entries > max do
    table.remove(M._entries)
  end

  M.save()
end

function M.format_time(timestamp, lang)
  local diff = os.time() - timestamp
  local is_zh = lang == "zh-TW"
  if diff < 60 then return diff .. (is_zh and "秒前" or "s ago") end
  if diff < 3600 then return math.floor(diff / 60) .. (is_zh and "分鐘前" or "m ago") end
  if diff < 86400 then return math.floor(diff / 3600) .. (is_zh and "小時前" or "h ago") end
  return math.floor(diff / 86400) .. (is_zh and "天前" or "d ago")
end

return M
