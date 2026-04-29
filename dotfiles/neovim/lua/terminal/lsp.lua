vim.keymap.set("n", "<S-l>", vim.diagnostic.open_float, { desc = "Diagnostic modal" })
vim.keymap.set("n", "[l", function()
	vim.diagnostic.jump({ count = -1 })
end, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]l", function()
	vim.diagnostic.jump({ count = 1 })
end, { desc = "Next diagnostic" })
vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration" })
vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
vim.keymap.set("n", "gn", vim.lsp.buf.rename, { desc = "Rename variable" })
vim.keymap.set({ "n", "v" }, "ga", vim.lsp.buf.code_action, { desc = "Code actions" })
vim.keymap.set("n", "gl", vim.lsp.codelens.run, { desc = "Run code lens" })
vim.keymap.set("n", [[\d]], function()
	vim.diagnostic.reset(nil, vim.api.nvim_get_current_buf())
end, { desc = "Toggle diagnostics for buffer" })
vim.keymap.set("n", [[\i]], function()
	vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
end, { desc = "Toggle inlay hints" })
vim.keymap.set("n", "gr", vim.lsp.buf.references)
vim.keymap.set("n", [[\l]], function()
	vim.lsp.codelens.enable(not vim.lsp.codelens.is_enabled({ bufnr = 0 }), { bufnr = 0 })
end, { desc = "Toggle code lenses" })

-- Source: https://github.com/neovim/nvim-lspconfig/wiki/UI-Customization#borders
local original_open_floating_preview = vim.lsp.util.open_floating_preview
---@diagnostic disable-next-line: duplicate-set-field
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
	opts = opts or {}
	opts.border = opts.border or "rounded"
	opts.focusable = opts.focusable or true
	-- TODO: This isn't being respected, I should open an issue
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
		assert(client ~= nil)
		client.server_capabilities.semanticTokensProvider = nil
	end,
})

require("nvim-lightbulb").setup({
	autocmd = { enabled = true },
	sign = { enabled = false },
	virtual_text = {
		enabled = true,
		text = "",
		hl = "CodeActionSign",
	},
})

-- An error is printed if nix isn't available
if vim.fn.executable("nix") == 1 then
	local excluded_servers = {
		-- Only use Ruff and ty for Python
		"pylyzer",
		"jedi_language_server",
		"pyright",
		"basedpyright",
		"pylsp",

		-- Use nixd instead
		"nil_ls",

		"quick_lint_js",
	}
	-- These language servers match a lot of file types so I'm only running them if
	-- their config file is present.
	local maybe_excluded_severs = {
		denols = { "deno.json", "deno.jsonc" },
		tailwindcss = { "tailwind.config.js" },
	}
	for name, files in pairs(maybe_excluded_severs) do
		if not next(vim.fs.find(files, { upward = true })) then
			table.insert(excluded_servers, name)
		end
	end

	require("lazy-lsp").setup({ excluded_servers = excluded_servers, use_vim_lsp_config = true })
end
