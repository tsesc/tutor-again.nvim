local M = {}

M.defaults = {
  keymap = "<leader>?",
  lang = "zh-TW",
  history = {
    max_entries = 500,
    path = vim.fn.stdpath("data") .. "/tutor-again/history.json",
  },
}

function M.build(opts)
  return vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
