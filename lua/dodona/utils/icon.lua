local devicons = require("nvim-web-devicons")

local M = {}

M.ICON_PADDING_LENGTH = 6
M.STATUS_PADDING_LENGTH = 3

-- Function to get the status icon and pad it
function M.get_status_icon(activity)
	if activity.has_correct_solution then
		return "✔" .. string.rep(" ", M.STATUS_PADDING_LENGTH - 1)
	elseif activity.has_solution then
		return "✖" .. string.rep(" ", M.STATUS_PADDING_LENGTH - 1)
	else
		return string.rep(" ", M.STATUS_PADDING_LENGTH)
	end
end

-- Function to get the appropriate icon
function M.get_icon(language)
	local icon, _ = devicons.get_icon_by_filetype(language, { default = true })
	local padding_needed = M.ICON_PADDING_LENGTH - (#icon or #"")
	return (icon or "") .. string.rep(" ", padding_needed)
end

return M
