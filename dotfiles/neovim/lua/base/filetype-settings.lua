-- vim:foldmethod=marker

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  nested = true,
  pattern = ".envrc",
  callback = function()
    vim.opt_local.filetype = "sh"
  end,
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  nested = true,
  pattern = "*/git/config",
  callback = function()
    vim.opt_local.filetype = "gitconfig"
  end,
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  nested = true,
  pattern = "*.{service,target}",
  callback = function()
    -- TODO: Why doesn't this work without `defer_fn`?
    vim.defer_fn(function()
      vim.opt_local.filetype = "systemd"
    end, 0)
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
