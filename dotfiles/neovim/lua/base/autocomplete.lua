-- autopairs, endwise, and bullets.vim don't work in vscode and I prefer vscode's autotag
if vim.g.vscode ~= nil then
  return
end

Plug("windwp/nvim-autopairs", {
  config = function()
    require("nvim-autopairs").setup({
      -- Don't add bracket pairs after quote.
      enable_afterquote = false,
      map_cr = false,
    })
  end,
})

Plug("windwp/nvim-ts-autotag")

-- Automatically add closing keywords (e.g. function/endfunction in vimscript)
Plug("RRethy/nvim-treesitter-endwise")
vim.keymap.set({ "n" }, "o", "A<CR>", { remap = true })

-- TODO: Support bullets in comments
Plug("bullets-vim/bullets.vim")
vim.g.bullets_outline_levels = {}
vim.g.bullets_pad_right = 0
-- no partial checkboxes
vim.g.bullets_checkbox_markers = " X"
-- I'm defining the mappings myself because there is no option to apply them to all filetypes
vim.g.bullets_set_mappings = 0
local function bullets_newline()
  -- my markdown linter says there should be a blank line in between list items
  vim.g.bullets_line_spacing = vim.tbl_contains({ "markdown" }, vim.bo.filetype)
      and 2
    or 1
  return "<Plug>(bullets-newline)"
end
-- When I creating the keymaps outside of an autocommand it didn't work so now I'm creating it the
-- same way bullets.vim does and it works. Not sure what the difference is, maybe something to do
-- with nvim-cmp's fallback()?
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    if vim.bo.buftype ~= "" then
      return
    end

    if not vim.tbl_contains({ "markdown" }, vim.bo.filetype) then
      return
    end

    vim.keymap.set(
      { "i" },
      "<CR>",
      bullets_newline,
      { expr = true, buffer = true, remap = true }
    )
    vim.keymap.set(
      { "n", "x" },
      "gN",
      "<Plug>(bullets-renumber)",
      { buffer = true, remap = true, desc = "Renumber list items" }
    )
    vim.keymap.set(
      { "n" },
      "gX",
      "<Plug>(bullets-toggle-checkbox)",
      { buffer = true, remap = true }
    )

    -- TODO: Added dot-repeat support. I can remove this when one of these issues are resolved:
    -- https://github.com/bullets-vim/bullets.vim/issues/137
    -- https://github.com/bullets-vim/bullets.vim/issues/90
    vim.keymap.set("n", "<Plug>(repeatable-bullets-demote)", function()
      vim.cmd([[
      silent! call repeat#set("\<Plug>(repeatable-bullets-demote)", v:count)
      ]])
      return [[<Plug>(bullets-demote)]]
    end, { expr = true, buffer = true, remap = true })
    vim.keymap.set("n", "<Plug>(repeatable-bullets-promote)", function()
      vim.cmd([[
      silent! call repeat#set("\<Plug>(repeatable-bullets-promote)", v:count)
      ]])
      return [[<Plug>(bullets-promote)]]
    end, { expr = true, buffer = true, remap = true })

    vim.keymap.set(
      { "i" },
      "<C-k>",
      "<Plug>(bullets-demote)",
      { buffer = true, remap = true }
    )
    vim.keymap.set(
      { "i" },
      "<C-j>",
      "<Plug>(bullets-promote)",
      { buffer = true, remap = true }
    )
    vim.keymap.set(
      { "n" },
      "<<",
      "<Plug>(repeatable-bullets-promote)",
      { buffer = true, remap = true }
    )
    vim.keymap.set(
      { "n" },
      ">>",
      "<Plug>(repeatable-bullets-demote)",
      { buffer = true, remap = true }
    )
  end,
})
