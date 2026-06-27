vim.keymap.set({ "n", "x" }, "j", "gj")
vim.keymap.set({ "n", "x" }, "k", "gk")

-- Move faster by holding control. This post[1] explains the rationale.
--
-- https://web.archive.org/web/20250121083948/https://nanotipsforvim.prose.sh/vertical-navigation-%E2%80%93-without-relative-line-numbers
vim.keymap.set({ "n", "x" }, "<C-j>", "6gj")
vim.keymap.set({ "n", "x" }, "<C-k>", "6gk")
vim.keymap.set({ "n", "x" }, "<C-h>", "6h")
vim.keymap.set({ "n", "x" }, "<C-l>", "6l")

-- Move to end of line
vim.keymap.set({ "i" }, "<C-e>", "<ESC>$a")
vim.keymap.set({ "n" }, "<C-e>", "$")

-- Move to first non-blank character in line
vim.keymap.set({ "i" }, "<C-a>", "<ESC>^i")
local function c_a(buffer)
	vim.keymap.set({ "n" }, "<C-a>", "^", { buffer = buffer })
end
c_a()
vim.api.nvim_create_autocmd("FileType", {
	pattern = "gitrebase",
	callback = function()
		c_a(true)
	end,
})

-- Jump between braces
vim.opt.matchpairs:append("<:>")
-- andymass/vim-matchup
vim.g.matchup_matchparen_offscreen = {}
vim.g.matchup_treesitter_disable_virtual_text = true
vim.g.matchup_matchparen_deferred = true
vim.g.matchup_matchparen_hi_surround_always = true
vim.keymap.set({ "n", "x" }, ";", "%", { remap = true })
vim.keymap.set({ "n", "x" }, "g;", "g%", { remap = true })
vim.keymap.set({ "n", "x" }, "];", "]%", { remap = true })
vim.keymap.set({ "n", "x" }, "[;", "[%", { remap = true })
vim.keymap.set({ "n", "x" }, "z;", "z%", { remap = true })
