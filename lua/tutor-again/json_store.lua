local M = {}

function M.create(opts)
  local S = {}
  S._entries = {}
  S._path = nil
  S._max = opts.max or 500
  S._save_timer = nil

  function S._set_path(path)
    S._path = path
  end

  function S._get_path()
    if S._path then return S._path end
    S._path = vim.fn.stdpath("state") .. "/tutor-again/" .. opts.filename
    return S._path
  end

  function S.load()
    local path = S._get_path()
    if vim.fn.filereadable(path) == 0 then
      S._entries = {}
      return
    end
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok or #lines == 0 then
      S._entries = {}
      return
    end
    local raw = table.concat(lines, "\n")
    local ok2, data = pcall(vim.fn.json_decode, raw)
    if ok2 and type(data) == "table" then
      S._entries = data
    else
      S._entries = {}
    end
  end

  function S._write_to_disk()
    local path = S._get_path()
    local dir = vim.fn.fnamemodify(path, ":h")
    vim.fn.mkdir(dir, "p")
    local ok, encoded = pcall(vim.fn.json_encode, S._entries)
    if ok then
      -- Atomic write: write to temp file then rename to reduce race window
      local tmp = path .. ".tmp." .. vim.fn.getpid()
      local wok = pcall(vim.fn.writefile, { encoded }, tmp)
      if wok then
        vim.fn.rename(tmp, path)
      end
    end
  end

  function S.save()
    if S._save_timer then
      S._save_timer:stop()
      S._save_timer = nil
    end
    S._save_timer = vim.defer_fn(function()
      S._save_timer = nil
      S._write_to_disk()
    end, 1000)
  end

  function S.clear()
    S._entries = {}
    if S._save_timer then
      S._save_timer:stop()
      S._save_timer = nil
    end
    local path = S._get_path()
    if vim.fn.filereadable(path) == 1 then
      vim.fn.delete(path)
    end
  end

  function S._merge_disk()
    local path = S._get_path()
    if vim.fn.filereadable(path) == 0 then return end
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok or #lines == 0 then return end
    local raw = table.concat(lines, "\n")
    local ok2, disk_data = pcall(vim.fn.json_decode, raw)
    if not ok2 or type(disk_data) ~= "table" then return end

    local seen = {}
    for _, entry in ipairs(S._entries) do
      local key = entry[opts.dedup_key]
      if key ~= nil then seen[key] = true end
    end
    for _, entry in ipairs(disk_data) do
      local key = entry[opts.dedup_key]
      if key ~= nil and not seen[key] then
        table.insert(S._entries, entry)
        seen[key] = true
      end
    end
  end

  function S.get_all()
    if #S._entries == 0 then
      S.load()
    end
    return S._entries
  end

  return S
end

return M
