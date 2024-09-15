local api = require("dodona.api")

local M = {}

-- Fetch and return the list of subscribed courses
function M.getSubscribedCourses()
	local result = api.get("", false)

	if not result or not result.body then
		vim.notify("Failed to fetch data from the server", "error")
		return {}
	end

	if not result.body.user then
		vim.notify("User data is missing in the response", "error")
		return {}
	end

	return result.body.user.subscribed_courses or {}
end

-- Get details of a specific course using its name, id, or year
function M.getCourse(name, id, year)
	local courses = M.getSubscribedCourses()

	if #courses == 0 then
		vim.notify("No subscribed courses found", "error")
		return nil
	end

	for _, course in ipairs(courses) do
		if course.name == name or course.id == id or course.year == year then
			return course
		end
	end

	vim.notify("Course not found", "warn")
	return nil
end

-- Subscribe to a course using its ID
function M.subscribe(course_id)
	local result = api.post("/courses/" .. course_id .. "/subscribe", {})

	if not result or result.status ~= 200 then
		vim.notify("Failed to subscribe to course ID: " .. course_id, "error")
		return {}
	end

	return result.body or {}
end

return M
