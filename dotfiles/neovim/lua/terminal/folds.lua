vim.o.foldlevelstart = 99
vim.opt.fillchars:append("fold: ")
vim.o.foldtext = ""
vim.o.foldmethod = "indent"
-- By default this is "#", but I want lines starting with "#" to get folded too.
vim.o.foldignore = ""

vim.keymap.set("n", "<Tab>", [[<Cmd>silent! normal! za<CR>]])

local function toggle_all_folds()
  if vim.o.foldlevel > 0 then
    return "zM"
  else
    return "zR"
  end
end
vim.keymap.set("n", "<S-Tab>", toggle_all_folds, { silent = true, expr = true })

-- Jump to the top and bottom of the current fold
vim.keymap.set({ "n", "x" }, "[<Tab>", "[z")
vim.keymap.set({ "n", "x" }, "]<Tab>", "]z")
