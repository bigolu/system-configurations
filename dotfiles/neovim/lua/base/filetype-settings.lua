-- vim:foldmethod=marker

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = ".envrc",
  callback = function()
    vim.opt_local.filetype = "sh"
  end,
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*/git/config",
  callback = function()
    vim.opt_local.filetype = "gitconfig"
  end,
})

-- For indentexpr
Plug("LnL7/vim-nix")

-- Tweak iskeyword {{{
vim.api.nvim_create_autocmd("FileType", {
  pattern = "txt",
  callback = function()
    vim.opt_local.iskeyword:append("_")
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "sh",
  callback = function()
    vim.opt_local.iskeyword:append("-")
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "css",
    "scss",
    "javascriptreact",
    "typescriptreact",
    "javascript",
    "typescript",
    "sass",
    "postcss",
  },
  callback = function()
    vim.opt_local.iskeyword:append("-,?,!")
  end,
})
-- }}}
