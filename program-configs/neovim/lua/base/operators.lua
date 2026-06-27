-- vim:foldmethod=marker

-- Copy up to the end of line, not including the newline character
vim.keymap.set({ "n" }, "Y", "yg_")

require("treesj").setup({
	use_default_keymaps = false,
	max_join_length = 200,
})
vim.keymap.set("n", "ss", vim.cmd.TSJToggle)
vim.keymap.set("n", "sS", function()
	require("treesj").toggle({
		join = { recursive = true },
		split = { recursive = true },
	})
end)

-- Extend the types of text that can be incremented/decremented {{{
local augend = require("dial.augend")

local function words(...)
	return augend.constant.new({
		elements = { ... },
		word = true,
		cyclic = true,
	})
end

local function symbols(...)
	return augend.constant.new({
		elements = { ... },
		word = false,
		cyclic = true,
	})
end

require("dial.config").augends:register_group({
	default = {
		-- color: #ffffff
		--
		-- If the cursor is over one of the two digits in the red, green, or blue
		-- value, it only increments that color of the hex. To increment the red,
		-- green, and blue portions, the cursor must be over the '#'.
		augend.hexcolor.new({ case = "prefer_lower" }),
		-- time: 14:30:00
		augend.date.alias["%H:%M:%S"],
		-- time: 14:30
		augend.date.alias["%H:%M"],
		-- decimal integer: 0, 4, -123
		augend.integer.alias.decimal_int,
		-- hex: 0x00
		augend.integer.alias.hex,
		-- binary: 0b0101
		augend.integer.alias.binary,
		-- octal: 0o00
		augend.integer.alias.octal,
		-- Semantic Versioning: 1.22.1
		augend.semver.alias.semver,
		-- uppercase letter: A
		augend.constant.alias.Alpha,
		-- lowercase letter: a
		augend.constant.alias.alpha,
		words("and", "or"),
		words("public", "private"),
		words("true", "false"),
		words("True", "False"),
		words("yes", "no"),
		symbols("&&", "||"),
		symbols("!=", "=="),
		symbols("!==", "==="),
		symbols("<", ">"),
		symbols("<=", ">="),
		symbols("+=", "-="),
	},
})

local manipulate = require("dial.map").manipulate
vim.keymap.set("n", "+", function()
	manipulate("increment", "normal")
end)
vim.keymap.set("n", "-", function()
	manipulate("decrement", "normal")
end)
vim.keymap.set("n", "g+", function()
	manipulate("increment", "gnormal")
end)
vim.keymap.set("n", "g-", function()
	manipulate("decrement", "gnormal")
end)
vim.keymap.set("v", "+", function()
	manipulate("increment", "visual")
end)
vim.keymap.set("v", "-", function()
	manipulate("decrement", "visual")
end)
vim.keymap.set("v", "g+", function()
	manipulate("increment", "gvisual")
end)
vim.keymap.set("v", "g-", function()
	manipulate("decrement", "gvisual")
end)
-- }}}
