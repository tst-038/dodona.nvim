local api = require("dodona.api")

local M = {}

-- Get the series available in a course
function M.getSeries(course_id)
	local result = api.get("/courses/" .. course_id .. "/series")

	if not result or result.status ~= 200 then
		vim.notify("Failed to fetch series for course ID: " .. course_id, "error")
		return {}
	end

	return result.body or {}
end

return M
