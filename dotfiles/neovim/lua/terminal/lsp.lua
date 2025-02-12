local methods = vim.lsp.protocol.Methods

vim.keymap.set("n", "<S-l>", vim.diagnostic.open_float, { desc = "Diagnostic modal [lint,problem]" })
vim.keymap.set("n", "[l", vim.diagnostic.goto_prev, { desc = "Previous diagnostic [last,lint,problem]" })
vim.keymap.set("n", "]l", vim.diagnostic.goto_next, { desc = "Next diagnostic [lint,problem]" })
vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration" })
vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
vim.keymap.set("n", "gn", vim.lsp.buf.rename, { desc = "Rename variable" })
vim.keymap.set({ "n", "v" }, "ga", vim.lsp.buf.code_action, { desc = "Code actions" })
vim.keymap.set("n", "gl", vim.lsp.codelens.run, { desc = "Run code lens" })
vim.keymap.set("n", [[\d]], function()
  vim.diagnostic.reset(nil, vim.api.nvim_get_current_buf())
end, { desc = "Toggle diagnostics for buffer" })
vim.keymap.set("n", [[\i]], function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(), { bufnr = 0 })
end, { desc = "Toggle inlay hints" })

-- Source: https://github.com/neovim/nvim-lspconfig/wiki/UI-Customization#borders
local original_open_floating_preview = vim.lsp.util.open_floating_preview
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
  opts = opts or {}
  opts.border = opts.border or { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
  opts.focusable = opts.focusable or true
  opts.max_height = opts.max_height or math.floor(vim.o.lines * 0.35)
  opts.max_width = math.min(80, math.floor(vim.o.columns * 0.65))

  return original_open_floating_preview(contents, syntax, opts, ...)
end

vim.diagnostic.config({
  signs = false,
  update_in_insert = true,
  virtual_text = { prefix = "" },
  float = { source = true },
})

vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach", "DiagnosticChanged" }, {
  callback = function(_)
    vim.cmd.redrawstatus()
  end,
})

-- Disable semantic highlights
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    client.server_capabilities.semanticTokensProvider = nil
  end,
})

-- codelens utils
local code_lens_refresh_autocmd_ids_by_buffer = {}
local function create_refresh_autocmd(buffer)
  local refresh_autocmd_id = code_lens_refresh_autocmd_ids_by_buffer[buffer]
  if refresh_autocmd_id ~= -1 then
    vim.notify(
      "Not creating another code lens refresh autocmd since it doesn't look like the old one was removed. The id of the old one is: "
        .. refresh_autocmd_id,
      vim.log.levels.ERROR
    )
    return
  end
  code_lens_refresh_autocmd_ids_by_buffer[buffer] = vim.api.nvim_create_autocmd({ "CursorHold", "InsertLeave" }, {
    desc = "code lens refresh",
    callback = function()
      vim.lsp.codelens.refresh({ bufnr = buffer })
    end,
    buffer = buffer,
  })
end
local function delete_refresh_autocmd(buffer)
  local refresh_autocmd_id = code_lens_refresh_autocmd_ids_by_buffer[buffer]
  if refresh_autocmd_id == -1 then
    vim.notify("Unable to to remove the code lens refresh autocmd because its id was not found", vim.log.levels.ERROR)
    return
  end
  vim.api.nvim_del_autocmd(refresh_autocmd_id)
  code_lens_refresh_autocmd_ids_by_buffer[buffer] = -1
end

vim.api.nvim_create_autocmd("LspAttach", {
  -- Should be idempotent since it may be called multiple times for the same buffer
  -- if a server registers a capability dynamically.
  callback = function(context)
    local client = context.data.client
    local buffer = context.data.buffer

    if client.supports_method(methods.textDocument_codeLens) then
      if code_lens_refresh_autocmd_ids_by_buffer[buffer] == nil then
        code_lens_refresh_autocmd_ids_by_buffer[buffer] = -1
        create_refresh_autocmd(buffer)
      end

      vim.keymap.set("n", [[\l]], function()
        local refresh_autocmd_id = code_lens_refresh_autocmd_ids_by_buffer[buffer]
        local is_refresh_autocmd_active = refresh_autocmd_id ~= -1
        if is_refresh_autocmd_active then
          delete_refresh_autocmd(buffer)
          vim.lsp.codelens.clear(client.id, buffer)
        else
          create_refresh_autocmd(buffer)
        end
      end, { desc = "Toggle code lenses", buffer = buffer })
    end
  end,
})

Plug("kosayoda/nvim-lightbulb", function()
  require("nvim-lightbulb").setup({
    autocmd = { enabled = true },
    sign = { enabled = false },
    virtual_text = {
      enabled = true,
      text = "",
      hl = "CodeActionSign",
    },
  })
end)

Plug("neovim/nvim-lspconfig")

-- An error is printed if nix isn't available
if vim.fn.executable("nix") == 1 then
  Plug("dundalek/lazy-lsp.nvim", function()
    local excluded_servers = {
      "pylyzer",
      "jedi_language_server",
      "basedpyright",
      "pylsp",
      "nil_ls",
      "quick_lint_js",
    }
    -- TODO: See if it makes sense to upstream this to nvim-lspconfig. Some of
    -- these files are optional so it wouldn't make sense to upstream those.
    local maybe_excluded_severs = {
      denols = { "deno.json", "deno.jsonc" },
      tailwindcss = { "tailwind.config.js" },
    }
    for name, files in pairs(maybe_excluded_severs) do
      if not next(vim.fs.find(files, { upward = true })) then
        table.insert(excluded_servers, name)
      end
    end

    require("lazy-lsp").setup({
      prefer_local = true,
      excluded_servers = excluded_servers,
    })
  end)
end
