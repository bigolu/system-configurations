-- vim:foldmethod=marker

vim.o.timeout = false
vim.o.updatetime = 500
vim.o.swapfile = false
vim.o.fileformats = "unix,dos,mac"
vim.o.paragraphs = ""
vim.o.sections = ""
vim.keymap.set({ "i" }, "jk", "<Esc>")

-- Only use the system's clipboard when neovim is running locally.
local is_ssh_active = #(os.getenv("SSH_TTY") or "") > 0
if not is_ssh_active then
	vim.o.clipboard = "unnamedplus"
end

-- Prevents inserting two spaces after punctuation on a join (J)
vim.o.joinspaces = false

-- Enter a newline above or below the current line.
vim.keymap.set({ "n" }, "<Enter>", "o<ESC>", {
	desc = "Insert newline above",
})
vim.keymap.set({ "n" }, "<S-Enter>", "O<ESC>", {
	desc = "Insert newline below",
})

-- leave cursor at the end of yanked text
vim.keymap.set({ "x" }, "y", "ygv<Esc>", { silent = true })

-- Stop treating <Esc> as ctrl-[
vim.keymap.set({ "n", "i", "v", "x" }, "<Esc>", "<Esc>", { noremap = true })

-- paste {{{
function Paste(was_in_visual_mode, is_capital_p, last_register, last_count)
	local register = was_in_visual_mode and last_register or vim.v.register
	local register_contents = vim.fn.getreg(register) or ""
	local is_multi_line_paste = register_contents:find("\n")
	local count = was_in_visual_mode and last_count or vim.v.count1

	if is_multi_line_paste then
		-- When you yank multiple lines in vim it always appends a newline to the
		-- end so the lines don't interleave with the text where you paste. I'm
		-- doing that here as well to account for text that is copied outside of
		-- vim.
		if register_contents:sub(-1) ~= "\n" then
			register_contents = register_contents .. "\n"
			vim.fn.setreg(register, "\n", "a")
		end
	end

	-- In visual mode, single line pastes at the end of the line or multi-line
	-- pastes at the last line must use 'p'.
	local is_paste_at_end = (
		was_in_visual_mode
		and not is_multi_line_paste
		and (vim.fn.col("'>") == (vim.fn.col("$") - 1))
	) or (was_in_visual_mode and is_multi_line_paste and (vim.fn.line("'>") == (vim.fn.line("$"))))

	local go_back_to_visual = was_in_visual_mode and "gv" or ""
	-- Don't overwrite the clipboard.
	local delete_into_blackhole = was_in_visual_mode and '"_d' or ""
	local paste = count .. [["]] .. register .. ((is_capital_p and not is_paste_at_end) and "P" or "p")
	local go_to_end_of_paste = is_multi_line_paste and "`]" or ""
	vim.api.nvim_feedkeys(go_back_to_visual .. delete_into_blackhole .. paste .. go_to_end_of_paste, "n", false)
end
vim.keymap.set({ "n" }, "p", function()
	Paste(false, false)
end, { silent = true })
-- In visual mode p should behave like P.
vim.keymap.set({ "x" }, "p", "P", { silent = true, remap = true })
vim.keymap.set({ "n" }, "P", function()
	Paste(false, true)
end, { silent = true })
-- Leave visual mode so '< and '> get set, but save the current register
-- beforehand
vim.keymap.set(
	{ "x" },
	"P",
	"<Cmd>lua LastReg = vim.v.register; LastCount = vim.v.count1<CR><Esc>:lua local last_reg, last_count = LastReg, LastCount; LastReg, LastCount = nil, nil; Paste(true, true, last_reg, last_count)<CR>",
	{ silent = true }
)
-- }}}

-- Disable features {{{
-- Disable unused builtin plugins.
local plugins_to_disable = {
	"getscript",
	"getscriptPlugin",
	"vimball",
	"vimballPlugin",
	"2html_plugin",
	"logipat",
	"rrhelper",
	"spellfile_plugin",
	"matchit",
}
for _, plugin in pairs(plugins_to_disable) do
	vim.g["loaded_" .. plugin] = 1
end

-- Disable language providers. Feels like a lot of trouble to install neovim
-- bindings for all these languages so I'll just avoid plugins that require
-- them. By disabling the providers, I won't get a warning about missing
-- bindings when I run `:checkhealth`.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0

-- I have a mapping for `gr` so having mappings with a prefix of `gr` would make
-- vim wait for more input before executing the `gr` mapping.
vim.keymap.del({ "n" }, "grt")
vim.keymap.del({ "n" }, "gri")
vim.keymap.del({ "n" }, "grr")
vim.keymap.del({ "n" }, "gra")
vim.keymap.del({ "n" }, "grn")
-- }}}

-- Option overrides {{{
vim.api.nvim_create_autocmd("FileType", {
	callback = function()
		-- Don't automatically hard-wrap text
		vim.bo.wrapmargin = 0
		-- r: Automatically insert the current comment leader after hitting
		--   <Enter> in Insert mode.
		-- o: Automatically insert the current comment leader after hitting o/O
		--   in normal mode.
		-- /: Don't auto insert a comment leader if the comment is next to a
		--   statement.
		-- j: Remove comment leader when joining lines
		vim.bo.formatoptions = "ro/j"

		if vim.o.filetype == "gitcommit" then
			vim.bo.formatoptions = vim.bo.formatoptions .. "t"
			vim.bo.textwidth = 80
		end
	end,
})
-- }}}

-- Substitutions {{{
-- Autocommands get executed without `smagic` so I make sure that I explicitly
-- specify it on the commandline so if my autocommand has a substitute command
-- it will use `smagic`.
vim.keymap.set({ "ca" }, "s", function()
	local cmdline = vim.fn.getcmdline()
	if vim.fn.getcmdtype() == ":" and (cmdline == "s" or cmdline == [['<,'>s]]) then
		return "smagic"
	else
		return "s"
	end
end, { expr = true })
-- TODO: I can't get this to work as part of the above mapping for some reason.
vim.keymap.set({ "ca" }, "%s", function()
	if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "%s" then
		return "%smagic"
	else
		return "%s"
	end
end, { expr = true })
-- }}}
