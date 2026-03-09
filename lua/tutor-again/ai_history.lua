local store = require("tutor-again.json_store")
local M = store.create({
  filename = "ai_history.json",
  max = 100,
  dedup_key = "id",
})

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

return M
