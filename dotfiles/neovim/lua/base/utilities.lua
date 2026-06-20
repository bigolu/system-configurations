local M = {}

function M.get_char()
	local ret_val, char_num = pcall(vim.fn.getchar)
	assert(type(char_num) == "number")

	-- Return nil if error (e.g. <C-c>) or for control characters
	if not ret_val or char_num < 32 then
		return nil
	end

	return vim.fn.nr2char(char_num)
end

return M
