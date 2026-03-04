vim.opt.runtimepath:prepend(vim.fn.getcwd())

local mini_path = vim.fn.stdpath("data") .. "/site/pack/deps/start/mini.nvim"
if vim.fn.isdirectory(mini_path) == 0 then
  vim.fn.system({ "git", "clone", "https://github.com/echasnovski/mini.nvim", mini_path })
end
vim.opt.runtimepath:prepend(mini_path)

require("mini.test").setup()
