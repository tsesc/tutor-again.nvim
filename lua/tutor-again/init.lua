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
    else
      require("tutor-again.ui").open()
    end
  end, {
    nargs = "?",
    complete = function()
      return { "history", "categories" }
    end,
    desc = "Open tutor-again",
  })

  local key = M.config.keymap
  if key and key ~= "" then
    vim.keymap.set("n", key, "<cmd>TutorAgain<CR>", { desc = "tutor-again: open", silent = true })
  end
end

return M
