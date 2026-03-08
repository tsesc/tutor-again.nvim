local M = {}

M.defaults = {
  keymap = "<leader>?",
  lang = "zh-TW",
  history = {
    max_entries = 500,
    path = vim.fn.stdpath("state") .. "/tutor-again/history.json",
  },
  ai = {
    enabled = true,
    api_key = nil, -- fallback: $GEMINI_API_KEY
    base_url = "https://generativelanguage.googleapis.com/v1beta/openai",
    model = "gemini-2.5-flash-lite",
    mode_key = "<C-a>",
    include_config = false, -- false | true | { "path1", "path2" }
  },
}

function M.build(opts)
  return vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
