vim.o.complete = ".,w,b,u"
vim.o.pumheight = 6
vim.o.completeopt = "menu,menuone,popup,fuzzy,noselect"

require("nvim-ts-autotag").setup()

-- RRethy/nvim-treesitter-endwise
-- Automatically add closing keywords (e.g. function/endfunction in vimscript)
vim.keymap.set({ "n" }, "o", "A<CR>", { remap = true })
