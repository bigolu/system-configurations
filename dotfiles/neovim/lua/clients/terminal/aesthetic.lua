vim.o.linebreak = true
vim.o.breakat = " ^I"
vim.o.cursorline = true
vim.o.cursorlineopt = "number"
vim.o.wrap = true
vim.o.listchars = "tab:¬-,space:·"
vim.opt.fillchars:append("eob: ,lastline:>")

vim.cmd.colorscheme("bigolu")
vim.api.nvim_create_autocmd({ "OptionSet" }, {
  pattern = "termguicolors",
  callback = function(_)
    vim.cmd.colorscheme("bigolu")
  end,
})

-- cursor
-- I don't think I'll need to reset/restore the cursor once this issue is resolved:
-- https://github.com/neovim/neovim/issues/4396
local blink = "blinkwait0-blinkon150-blinkoff150"
local bar = "ver25"
local function set_cursor()
  -- Block cursor in normal mode, thin line in insert mode, and underline in replace
  -- mode
  vim.o.guicursor = string.format("n-v:block-%s,i-c-ci-ve:%s-%s,r-cr-o:hor20-%s", blink, bar, blink, blink)
end
local function reset_cursor()
  vim.o.guicursor = string.format("a:%s-%s", bar, blink)
end
set_cursor()
vim.api.nvim_create_autocmd({ "VimLeave", "VimSuspend" }, {
  callback = reset_cursor,
})
vim.api.nvim_create_autocmd({ "VimResume" }, {
  callback = set_cursor,
})
