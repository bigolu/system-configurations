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

-- Every time we enter a buffer, reset the fold options. This avoids the issue
-- where you set a foldmethod because the attached LSP server supports
-- it, but then switch to another buffer and the foldmethod is still set to
-- LSP. Your other fold providers think that LSP folding is active and don't
-- override it. With this autocmd, there will never be "stale" fold options
-- because they will always get reset. Though this means that all fold providers
-- have to set fold options every time the buffer is entered. I expected this
-- to be a problem with modelines, but it seems to work. I put the autocmd here
-- because it needs to fire before the autocmds of any fold providers.
vim.api.nvim_create_autocmd({ "BufRead" }, {
  callback = function()
    vim.cmd([[
      setlocal foldmethod&
      setlocal foldexpr&
    ]])
  end,
})

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

local function maybe_set_lsp_fold_method(client)
  local is_foldmethod_overridable = not vim.tbl_contains({ "marker", "diff" }, vim.wo.foldmethod)
  if not is_foldmethod_overridable or not client:supports_method("textDocument/foldingRange") then
    return
  end

  vim.wo.foldmethod = "expr"
  vim.wo.foldexpr = "v:lua.vim.lsp.foldexpr()"
end
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    maybe_set_lsp_fold_method(client)
  end,
})
vim.api.nvim_create_autocmd({ "BufEnter" }, {
  callback = function(args)
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = args.buf })) do
      maybe_set_lsp_fold_method(client)
    end
  end,
})
