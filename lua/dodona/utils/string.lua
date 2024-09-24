local M = {}

function M.pad_number(num, total_series)
	return string.format("%0" .. total_series .. "d", num)
end

-- Helper function to pad activity name to a specific length
function M.pad_string(str, length)
	local str_width = vim.fn.strdisplaywidth(str)
	local padding = length - str_width
	if padding > 0 then
		return str .. string.rep(" ", padding)
	else
		return str
	end
end

return M
