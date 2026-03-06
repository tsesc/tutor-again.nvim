local M = {}

M._entries = {}
M._path = nil
M._max = 500
M._save_timer = nil

function M._set_path(path)
  M._path = path
end

function M._get_path()
  if M._path then return M._path end
  local config = require("tutor-again").config
  if config.history and config.history.path then
    M._path = config.history.path
  else
    M._path = vim.fn.stdpath("state") .. "/tutor-again/history.json"
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

function M.load()
  local path = M._get_path()
  if vim.fn.filereadable(path) == 0 then
    M._entries = {}
    return
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or #lines == 0 then
    M._entries = {}
    return
  end
  local raw = table.concat(lines, "\n")
  local ok2, data = pcall(vim.fn.json_decode, raw)
  if ok2 and type(data) == "table" then
    M._entries = data
  else
    M._entries = {}
  end
end

function M._write_to_disk()
  local path = M._get_path()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  local ok, encoded = pcall(vim.fn.json_encode, M._entries)
  if ok then
    -- Atomic write: write to temp file then rename to reduce race window
    local tmp = path .. ".tmp." .. vim.fn.getpid()
    local wok = pcall(vim.fn.writefile, { encoded }, tmp)
    if wok then
      vim.fn.rename(tmp, path)
    end
  end
end

function M.save()
  if M._save_timer then
    M._save_timer:stop()
    M._save_timer = nil
  end
  M._save_timer = vim.defer_fn(function()
    M._save_timer = nil
    M._write_to_disk()
  end, 1000)
end

function M.clear()
  M._entries = {}
  if M._save_timer then
    M._save_timer:stop()
    M._save_timer = nil
  end
  local path = M._get_path()
  if vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
  end
end

function M._merge_disk()
  local path = M._get_path()
  if vim.fn.filereadable(path) == 0 then return end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or #lines == 0 then return end
  local raw = table.concat(lines, "\n")
  local ok2, disk_data = pcall(vim.fn.json_decode, raw)
  if not ok2 or type(disk_data) ~= "table" then return end

  local seen = {}
  for _, entry in ipairs(M._entries) do
    seen[entry.query] = true
  end
  for _, entry in ipairs(disk_data) do
    if not seen[entry.query] then
      table.insert(M._entries, entry)
      seen[entry.query] = true
    end
  end
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

function M.get_all()
  if #M._entries == 0 then
    M.load()
  end
  return M._entries
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
