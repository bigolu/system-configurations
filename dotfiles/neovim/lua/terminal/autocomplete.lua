vim.o.complete = ".,w,b,u"
vim.o.pumheight = 6
vim.o.completeopt = "menu,menuone,popup,fuzzy,noselect"

Plug("windwp/nvim-autopairs", function()
  require("nvim-autopairs").setup({
    -- Don't add bracket pairs after quote.
    enable_afterquote = false,
    map_cr = false,
  })
end)

Plug("windwp/nvim-ts-autotag", function()
  require("nvim-ts-autotag").setup()
end)

-- Automatically add closing keywords (e.g. function/endfunction in vimscript)
Plug("RRethy/nvim-treesitter-endwise")
vim.keymap.set({ "n" }, "o", "A<CR>", { remap = true })
