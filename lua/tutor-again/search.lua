local M = {}

function M.score(query, str)
  if query == "" then return 1 end
  local ql = query:lower()
  local sl = str:lower()
  local qi = 1
  local sc = 0
  local prev_match = false

  for si = 1, #sl do
    if sl:sub(si, si) == ql:sub(qi, qi) then
      if prev_match then sc = sc + 10 end
      if si == 1 then sc = sc + 3 end
      if si > 1 then
        local prev = sl:sub(si - 1, si - 1)
        if prev == " " or prev == "_" or prev == "-" or prev == "." then
          sc = sc + 5
        end
      end
      sc = sc + 1
      prev_match = true
      qi = qi + 1
      if qi > #ql then return sc end
    else
      prev_match = false
    end
  end

  return 0
end

-- Category aliases for common search keywords
local category_aliases = {
  movement = { "control", "navigate", "cursor", "move", "scroll", "jump", "go", "控制", "移動", "游標", "跳" },
  operators = { "edit", "operator", "modify", "操作", "編輯", "修改" },
  text_objects = { "select", "object", "range", "選取", "物件", "範圍" },
  insert = { "type", "input", "write", "輸入", "打字", "寫" },
  visual = { "select", "highlight", "mark", "選取", "標記", "反白" },
  search = { "find", "replace", "match", "pattern", "搜尋", "尋找", "取代", "替換" },
  files = { "buffer", "window", "tab", "split", "file", "檔案", "視窗", "分割", "頁籤" },
  settings = { "option", "config", "set", "設定", "選項", "配置" },
  plugins = { "plugin", "package", "extension", "套件", "插件", "擴充" },
}

function M.best_score(query, entry)
  local best = 0
  best = math.max(best, M.score(query, entry.keys))
  best = math.max(best, M.score(query, entry.name))
  if entry.name_zh then
    best = math.max(best, M.score(query, entry.name_zh))
  end
  if entry.tags then
    for _, tag in ipairs(entry.tags) do
      best = math.max(best, M.score(query, tag))
    end
  end
  if entry.description then
    best = math.max(best, M.score(query, entry.description))
  end
  if entry.category then
    best = math.max(best, M.score(query, entry.category))
    -- Check category aliases
    local top = entry.category:match("^([^.]+)")
    if top and category_aliases[top] then
      for _, alias in ipairs(category_aliases[top]) do
        best = math.max(best, M.score(query, alias))
      end
    end
  end
  return best
end

function M.filter_entries(query, entries)
  if query == "" then return vim.list_slice(entries) end

  local scored = {}
  for _, entry in ipairs(entries) do
    local s = M.best_score(query, entry)
    if s > 0 then
      table.insert(scored, { entry = entry, score = s })
    end
  end

  table.sort(scored, function(a, b) return a.score > b.score end)

  local result = {}
  for _, v in ipairs(scored) do
    table.insert(result, v.entry)
  end
  return result
end

return M
