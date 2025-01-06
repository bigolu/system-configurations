vim.o.linebreak = true
vim.o.breakat = " ^I"
vim.o.cursorline = true
vim.o.cursorlineopt = "number,screenline"
vim.o.wrap = true
vim.o.listchars = "tab:¬-,space:·"
vim.opt.fillchars:append("eob: ,lastline:>")

vim.cmd.colorscheme("bigolu")
vim.api.nvim_create_autocmd({ "OptionSet" }, {
  pattern = "termguicolors",
  callback = function()
    vim.cmd.colorscheme("bigolu")
  end,
})

-- cursor
local function set_cursor()
  -- Block cursor in normal mode, thin line in insert mode, and underline in replace
  -- mode
  vim.o.guicursor =
    "n-v:block-blinkon0,i-c-ci-ve:ver25-blinkwait0-blinkon200-blinkoff200,r-cr-o:hor20-blinkwait0-blinkon200-blinkoff200"
end
local function reset_cursor()
  -- Reset terminal cursor to blinking bar.
  -- TODO: This won't be necessary once neovim starts doing this automatically.
  -- Issue: https://github.com/neovim/neovim/issues/4396
  vim.o.guicursor = "a:ver25-blinkwait0-blinkon200-blinkoff200"
end
set_cursor()
vim.api.nvim_create_autocmd({ "VimLeave", "VimSuspend" }, {
  callback = reset_cursor,
})
vim.api.nvim_create_autocmd({ "VimResume" }, {
  callback = set_cursor,
})
