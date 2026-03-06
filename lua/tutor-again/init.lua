local M = {}

M.config = {}

function M.setup(opts)
  M.config = require("tutor-again.config").build(opts)

  vim.api.nvim_create_user_command("TutorAgain", function(cmd)
    local arg = cmd.args
    if arg == "history" then
      require("tutor-again.ui").open_history()
    elseif arg == "categories" then
      require("tutor-again.ui").open_categories()
    elseif arg == "ai" then
      require("tutor-again.ui").open({ mode = "ai" })
    elseif arg == "clear-history" then
      require("tutor-again.history").clear()
      vim.notify("tutor-again: history cleared", vim.log.levels.INFO)
    else
      require("tutor-again.ui").open()
    end
  end, {
    nargs = "?",
    complete = function()
      return { "history", "categories", "ai", "clear-history" }
    end,
    desc = "Open tutor-again",
  })

  local key = M.config.keymap
  if key and key ~= "" then
    vim.keymap.set("n", key, "<cmd>TutorAgain<CR>", { desc = "tutor-again: open", silent = true })
  end
end

return M
