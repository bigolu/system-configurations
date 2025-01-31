vim.o.foldlevelstart = 99
vim.opt.fillchars:append("fold: ")
vim.o.foldtext = ""

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

vim.api.nvim_create_autocmd({ "BufEnter" }, {
  callback = function(_)
    local is_foldmethod_overridable = not vim.tbl_contains({ "marker", "diff", "expr" }, vim.wo.foldmethod)
    if not is_foldmethod_overridable then
      return
    end

    if require("nvim-treesitter.parsers").has_parser() then
      vim.wo.foldmethod = "expr"
      vim.wo.foldexpr = "nvim_treesitter#foldexpr()"
    else
      vim.wo.foldmethod = "indent"
    end
  end,
})
