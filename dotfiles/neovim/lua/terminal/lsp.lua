local methods = vim.lsp.protocol.Methods
local autocmd_group = vim.api.nvim_create_augroup("bigolu/lsp", {})

vim.keymap.set(
  "n",
  "<S-l>",
  vim.diagnostic.open_float,
  { desc = "Diagnostic modal [lint,problem]" }
)
vim.keymap.set(
  "n",
  "[l",
  vim.diagnostic.goto_prev,
  { desc = "Previous diagnostic [last,lint,problem]" }
)
vim.keymap.set(
  "n",
  "]l",
  vim.diagnostic.goto_next,
  { desc = "Next diagnostic [lint,problem]" }
)
vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Declaration" })
vim.keymap.set("n", "gn", vim.lsp.buf.rename, { desc = "Rename variable" })
vim.keymap.set(
  { "n", "v" },
  "ga",
  vim.lsp.buf.code_action,
  { desc = "Code actions" }
)
vim.keymap.set("n", [[\d]], function()
  vim.diagnostic.reset(nil, vim.api.nvim_get_current_buf())
end, { desc = "Toggle diagnostics for buffer" })
vim.keymap.set("n", [[\i]], function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(), { bufnr = 0 })
end, { desc = "Toggle inlay hints" })
vim.keymap.set("n", "gl", vim.lsp.codelens.run, { desc = "Run code lens" })

-- Source: https://github.com/neovim/nvim-lspconfig/wiki/UI-Customization#borders
local original_open_floating_preview = vim.lsp.util.open_floating_preview
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
  opts = opts or {}
  opts.border = opts.border
    or { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
  opts.focusable = opts.focusable or true
  opts.max_height = opts.max_height or math.floor(vim.o.lines * 0.35)
  opts.max_width = math.min(80, math.floor(vim.o.columns * 0.65))

  return original_open_floating_preview(contents, syntax, opts, ...)
end

vim.diagnostic.config({
  signs = false,
  virtual_text = {
    prefix = "",
  },
  update_in_insert = true,
  -- With this enabled, sign priorities will become:
  -- hint=11, info=12, warn=13, error=14
  severity_sort = true,
  float = {
    source = true,
    focusable = true,
    format = function(diagnostic)
      local result = diagnostic.message

      local code = diagnostic.code
      if code ~= nil then
        result = result .. string.format(" [%s]", code)
      end

      return result
    end,
  },
})

-- Hide all semantic highlights
vim.api.nvim_create_autocmd("ColorScheme", {
  group = autocmd_group,
  callback = function()
    local highlights = vim.fn.getcompletion("@lsp", "highlight") or {}
    for _, group in ipairs(highlights) do
      vim.api.nvim_set_hl(0, group, {})
    end
  end,
})

-- TODO: Fire a single event for when a server first starts _and_ when it registers a
-- capability dynamically. This should be simpler once this issue is resolved:
--
-- https://github.com/neovim/neovim/issues/24229
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    vim.api.nvim_exec_autocmds("User", {
      pattern = "LspAttach",
      data = {
        client = vim.lsp.get_client_by_id(args.data.client_id),
        buffer = args.buf,
      },
    })
  end,
})
local original_register_capability =
  vim.lsp.handlers[methods.client_registerCapability]
vim.lsp.handlers[methods.client_registerCapability] = function(err, res, ctx)
  local original_return_value = { original_register_capability(err, res, ctx) }

  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if client then
    vim.iter(vim.lsp.get_buffers_by_client_id(client.id)):each(function(buf)
      vim.api.nvim_exec_autocmds("User", {
        pattern = "LspAttach",
        data = {
          client = client,
          buffer = buf,
        },
      })
    end)
  end

  return unpack(original_return_value)
end

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
  code_lens_refresh_autocmd_ids_by_buffer[buffer] = vim.api.nvim_create_autocmd(
    { "CursorHold", "InsertLeave" },
    {
      desc = "code lens refresh",
      callback = function()
        vim.lsp.codelens.refresh({ bufnr = buffer })
      end,
      buffer = buffer,
    }
  )
end
local function delete_refresh_autocmd(buffer)
  local refresh_autocmd_id = code_lens_refresh_autocmd_ids_by_buffer[buffer]
  if refresh_autocmd_id == -1 then
    vim.notify(
      "Unable to to remove the code lens refresh autocmd because its id was not found",
      vim.log.levels.ERROR
    )
    return
  end
  vim.api.nvim_del_autocmd(refresh_autocmd_id)
  code_lens_refresh_autocmd_ids_by_buffer[buffer] = -1
end

vim.api.nvim_create_autocmd("User", {
  pattern = "LspAttach",

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
        local refresh_autocmd_id =
          code_lens_refresh_autocmd_ids_by_buffer[buffer]
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

-- TODO: ruff's language server fails because this plugin doesn't pass a 'range'
-- field.
Plug("kosayoda/nvim-lightbulb", {
  config = function()
    require("nvim-lightbulb").setup({
      autocmd = { enabled = true },
      sign = { enabled = false },
      virtual_text = {
        enabled = true,
        text = "",
        hl = "CodeActionSign",
      },
    })
  end,
})

Plug("neovim/nvim-lspconfig")

Plug("b0o/SchemaStore.nvim")

-- An error is printed if nix isn't available
if vim.fn.executable("nix") == 1 then
  Plug("dundalek/lazy-lsp.nvim", {
    config = function()
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

        configs = {
          jsonls = {
            settings = {
              json = {
                schemas = require("schemastore").json.schemas(),
                validate = { enable = true },
              },
            },
          },

          yamlls = {
            settings = {
              yaml = {
                schemas = require("schemastore").yaml.schemas(),
                -- For why this is needed see:
                -- https://github.com/b0o/SchemaStore.nvim?tab=readme-ov-file#usage
                schemaStore = {
                  enable = false,
                  url = "",
                },
              },
            },
          },
        },
      })

      -- re-trigger lsp attach so nvim-lsp-config has a chance to attach to any
      -- buffers that were opened before it was configured. This way I can load
      -- nvim-lsp-config asynchronously.
      --
      -- Set the filetype of all the currently open buffers to trigger a 'FileType'
      -- event for each buffer. This will trigger lsp attach
      vim.iter(vim.api.nvim_list_bufs()):each(function(buf)
        vim.bo[buf].filetype = vim.bo[buf].filetype
      end)
    end,
  })
end
