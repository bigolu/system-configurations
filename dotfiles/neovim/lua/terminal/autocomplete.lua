vim.o.complete = ".,w,b,u"
vim.o.pumheight = 6
vim.o.completeopt = "menu,menuone,popup,fuzzy,noselect"

-- Should be idempotent since it may be called multiple times for the same
-- buffer. For example, it could get called again if a server registers
-- another capability dynamically.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufnr = args.buf
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local methods = vim.lsp.protocol.Methods

    -- Enable completion
    if client.supports_method(methods.textDocument_completion) then
      vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
    end
  end,
})

local function feedkeys(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", true)
end

local function is_completion_menu_open()
  return tonumber(vim.fn.pumvisible()) ~= 0
end

local is_cursor_preceded_by_nonblank_character = function()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

local function trigger_autocomplete()
  -- TODO: A definition of get_clients in mini.nvim is being used by linters
  -- instead of the one from the neovim runtime. Since it has a different signature
  -- than the real one, linters think I'm calling it incorrectly.
  ---@diagnostic disable-next-line: redundant-parameter
  local is_any_lsp_server_running = next(vim.lsp.get_clients({ bufnr = 0 }))
  if is_any_lsp_server_running then
    vim.lsp.completion.trigger()
  else
    -- Buffer complete
    feedkeys("<C-n>")
  end
end

vim.keymap.set("i", "<Tab>", function()
  if is_completion_menu_open() then
    -- Select next entry
    feedkeys("<C-n>")
  elseif is_cursor_preceded_by_nonblank_character() then
    trigger_autocomplete()
  else
    feedkeys("<Tab>")
  end
end)

vim.keymap.set("i", "<C-Space>", trigger_autocomplete)

vim.keymap.set("i", "<S-Tab>", function()
  return is_completion_menu_open() and "<C-p>" or "<S-Tab>"
end, { expr = true })

vim.keymap.set("i", "<CR>", function()
  if is_completion_menu_open() then
    return "<Esc>a"
  else
    -- TODO: This function originally put its inputs through nvim_replace_termcodes,
    -- but that ended up with garbage being put in the document. I've overridden it
    -- to return whatever it was given, unmodified. It's original behavior is needed
    -- for other keymaps like <BS> So I have to restore it.
    local original = require("nvim-autopairs.utils").esc
    require("nvim-autopairs.utils").esc = function(x)
      return x
    end
    local return_value = require("nvim-autopairs").completion_confirm()
    require("nvim-autopairs.utils").esc = original

    return return_value
  end
end, { expr = true, noremap = true })

Plug("windwp/nvim-autopairs", {
  config = function()
    require("nvim-autopairs").setup({
      -- Don't add bracket pairs after quote.
      enable_afterquote = false,
      map_cr = false,
    })
  end,
})

Plug("windwp/nvim-ts-autotag", {
  config = function()
    require("nvim-ts-autotag").setup()
  end,
})

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
  if vim.tbl_contains({ "markdown" }, vim.bo.filetype) then
    vim.g.bullets_line_spacing = 2
  else
    vim.g.bullets_line_spacing = 1
  end

  return "<Plug>(bullets-newline)"
end
-- When I creating the keymaps outside of an autocommand it didn't work so now I'm creating it the
-- same way bullets.vim does and it works. Not sure what the difference is.
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    if vim.bo.buftype ~= "" then
      return
    end

    if not vim.tbl_contains({ "markdown" }, vim.bo.filetype) then
      return
    end

    vim.keymap.set({ "i" }, "<CR>", bullets_newline, { expr = true, buffer = true, remap = true })
    vim.keymap.set(
      { "n", "x" },
      "gN",
      "<Plug>(bullets-renumber)",
      { buffer = true, remap = true, desc = "Renumber list items" }
    )
    vim.keymap.set({ "n" }, "gX", "<Plug>(bullets-toggle-checkbox)", { buffer = true, remap = true })

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

    vim.keymap.set({ "i" }, "<C-k>", "<Plug>(bullets-demote)", { buffer = true, remap = true })
    vim.keymap.set({ "i" }, "<C-j>", "<Plug>(bullets-promote)", { buffer = true, remap = true })
    vim.keymap.set({ "n" }, "<<", "<Plug>(repeatable-bullets-promote)", { buffer = true, remap = true })
    vim.keymap.set({ "n" }, ">>", "<Plug>(repeatable-bullets-demote)", { buffer = true, remap = true })
  end,
})
