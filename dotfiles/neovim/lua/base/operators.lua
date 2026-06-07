-- vim:foldmethod=marker

-- for the globals defined by mini.nvim
---@diagnostic disable: undefined-global

-- Copy up to the end of line, not including the newline character
vim.keymap.set({ "n" }, "Y", "yg_", {
	desc = "Til end of line, excluding newline",
})

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

local defaults = {
	-- color: #ffffff
	--
	-- If the cursor is over one of the two digits in the red, green, or blue
	-- value, it only increments that color of the hex. To increment the red,
	-- green, and blue portions, the cursor must be over the '#'.
	hex_rgb = augend.hexcolor.new({ case = "prefer_lower" }),
	-- time: 14:30:00
	date_hms = augend.date.alias["%H:%M:%S"],
	-- time: 14:30
	date_hm = augend.date.alias["%H:%M"],
	-- decimal integer: 0, 4, -123
	int = augend.integer.alias.decimal_int,
	-- hex: 0x00
	hex = augend.integer.alias.hex,
	-- binary: 0b0101
	binary = augend.integer.alias.binary,
	-- octal: 0o00
	octal = augend.integer.alias.octal,
	-- Semantic Versioning: 1.22.1
	semver = augend.semver.alias.semver,
	-- uppercase letter: A
	Alpha = augend.constant.alias.Alpha,
	-- lowercase letter: a
	alpha = augend.constant.alias.alpha,
	logical_word = words("and", "or"),
	visibility = words("public", "private"),
	boolean = words("true", "false"),
	Boolean = words("True", "False"),
	confirm = words("yes", "no"),
	logical_symbol = symbols("&&", "||"),
	equality = symbols("!=", "=="),
	strict_equality = symbols("!==", "==="),
	lt_gt = symbols("<", ">"),
	lte_gte = symbols("<=", ">="),
	inc_dec = symbols("+=", "-="),
}

local function make_table(acc, _, item)
	table.insert(acc, item)
	return acc
end
local function extend_defaults(tweaks)
	return require("base.utilities").table_concat(
		vim.iter(defaults)
			:filter(function(index, _)
				return not vim.tbl_contains(tweaks.remove or {}, index)
			end)
			:fold({}, make_table),
		tweaks.add or {}
	)
end

require("dial.config").augends:register_group({
	default = vim.tbl_values(defaults),
})

local augends_for_js_based_languages = extend_defaults({
	add = {
		augend.constant.new({ elements = { "let", "const" } }),
	},
})

require("dial.config").augends:on_filetype({
	javascript = augends_for_js_based_languages,
	javascriptreact = augends_for_js_based_languages,
	typescript = augends_for_js_based_languages,
	typescriptreact = augends_for_js_based_languages,
	lua = extend_defaults({
		add = {
			symbols("~=", "=="),
		},
		remove = {
			"equality",
		},
	}),
	markdown = extend_defaults({
		add = {
			augend.misc.alias.markdown_header,
		},
	}),
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
