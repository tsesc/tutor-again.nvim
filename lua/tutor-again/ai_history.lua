local M = {}

M._entries = {}
M._path = nil
M._max = 100
M._save_timer = nil

function M._set_path(path)
  M._path = path
end

function M._get_path()
  if M._path then return M._path end
  M._path = vim.fn.stdpath("state") .. "/tutor-again/ai_history.json"
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
    seen[entry.id] = true
  end
  for _, entry in ipairs(disk_data) do
    if not seen[entry.id] then
      table.insert(M._entries, entry)
      seen[entry.id] = true
    end
  end
end

function M.add(question, response, lang)
  if not question or question == "" then return end
  if not response or response == "" then return end

  -- Merge disk entries from other instances into memory
  M._merge_disk()

  local now = os.time()
  -- Ensure unique ID even for rapid adds
  local id = now
  for _, entry in ipairs(M._entries) do
    if entry.id >= id then
      id = entry.id + 1
    end
  end

  -- Add to front
  table.insert(M._entries, 1, {
    id = id,
    question = question,
    response = response,
    lang = lang or "en",
    timestamp = now,
  })

  -- Trim
  local max = M._max
  local ok, ta = pcall(require, "tutor-again")
  if ok and ta.config and ta.config.ai and ta.config.ai.history_max_entries then
    max = ta.config.ai.history_max_entries
  end
  if max == 0 then
    M._entries = {}
    return
  end
  while #M._entries > max do
    table.remove(M._entries)
  end

  M.save()
end

function M.delete(id)
  for i, entry in ipairs(M._entries) do
    if entry.id == id then
      table.remove(M._entries, i)
      M.save()
      return true
    end
  end
  return false
end

function M.get_all()
  if #M._entries == 0 then
    M.load()
  end
  return M._entries
end

return M
