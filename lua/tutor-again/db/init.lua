local M = {}

local entries = nil

function M.all()
  if entries then return entries end
  entries = {}
  local modules = { "movement", "operators" }
  for _, mod in ipairs(modules) do
    local data = require("tutor-again.db." .. mod)
    for _, entry in ipairs(data) do
      table.insert(entries, entry)
    end
  end
  return entries
end

function M.reload()
  entries = nil
  return M.all()
end

return M
