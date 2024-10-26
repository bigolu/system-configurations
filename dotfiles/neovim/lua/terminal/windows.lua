-- open new horizontal and vertical panes to the right and bottom respectively
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.winminheight = 0
vim.o.winminwidth = 0
vim.keymap.set("n", "<C-\\>", vim.cmd.vsplit, {
  desc = "Vertical split",
})
vim.keymap.set("n", "<C-->", vim.cmd.split, {
  desc = "Horizontal split",
})
vim.keymap.set("n", "<C-_>", vim.cmd.split, {
  desc = "Horizontal split",
})

Plug("numToStr/Navigator.nvim", {
  config = function()
    require("Navigator").setup()
    vim.keymap.set({ "n", "t" }, "<M-h>", "<CMD>NavigatorLeft<CR>")
    vim.keymap.set({ "n", "t" }, "<M-l>", "<CMD>NavigatorRight<CR>")
    vim.keymap.set({ "n", "t" }, "<M-k>", "<CMD>NavigatorUp<CR>")
    vim.keymap.set({ "n", "t" }, "<M-j>", "<CMD>NavigatorDown<CR>")
  end,
})
