local devicons = require("nvim-web-devicons")
local courses = require("dodona.course.course")

local M = {}

M.ICON_PADDING_LENGTH = 4
M.STATUS_PADDING_LENGTH = 4

-- Helper function to get an icon and pad it
local function get_padded_icon(icon, padding_length)
	local icon_width = vim.fn.strwidth(icon)
	local padding_needed = padding_length - icon_width
	return icon .. string.rep(" ", math.max(0, padding_needed))
end

-- Function to get the status icon and pad it
function M.get_status_icon(activity)
	if activity.has_correct_solution and activity.last_solution_is_best then
		return get_padded_icon("★", M.STATUS_PADDING_LENGTH)
	elseif activity.has_correct_solution then
		return get_padded_icon("✔", M.STATUS_PADDING_LENGTH)
	elseif activity.has_solution then
		return get_padded_icon("✖", M.STATUS_PADDING_LENGTH)
	else
		return get_padded_icon(" ", M.STATUS_PADDING_LENGTH)
	end
end

-- Function to get the subscribed icon with padding
function M.get_subscribed_icon(course_id, subscribed_courses)
	if courses.isCourseSubscribed(course_id, subscribed_courses) then
		return get_padded_icon("✔", M.STATUS_PADDING_LENGTH)
	else
		return get_padded_icon(" ", M.STATUS_PADDING_LENGTH)
	end
end

-- Function to get the download all media icon with padding
function M.get_download_all_media_icon()
	return get_padded_icon("", M.ICON_PADDING_LENGTH)
end

-- Function to get the all activities icon with padding
function M.get_all_activities_icon()
	return get_padded_icon("", M.ICON_PADDING_LENGTH)
end

-- Function to get the all activities icon with padding
function M.get_all_series_icon()
	return get_padded_icon("", M.ICON_PADDING_LENGTH)
end

-- Function to get the appropriate filetype icon with padding
function M.get_icon(language)
	local icon, _ = devicons.get_icon_by_filetype(language, { default = true })
	return get_padded_icon(icon or "", M.ICON_PADDING_LENGTH)
end

return M
