-- vim:foldmethod=marker

local utilities = require("base.utilities")

vim.keymap.set({ "n", "x" }, "Q", function()
	local last_recorded_register = vim.fn.reg_recorded()
	if last_recorded_register ~= "" then
		return "@" .. last_recorded_register
	end
end, { remap = true, expr = true, desc = "Run last recorded macro" })

-- change macro
vim.keymap.set({ "n" }, "cq", function()
	local register = utilities.get_char()
	if register == nil then
		return
	end

	local macro_content = vim.fn.getreg(register)
	local input_config = {
		prompt = "Edit Macro [" .. register .. "]:",
		default = macro_content,
	}
	vim.ui.input(input_config, function(edited_macro)
		if not edited_macro then
			return
		end -- cancellation
		vim.fn.setreg(register, edited_macro)
	end)
end, {
	desc = "Change macro [edit,modify]",
})
