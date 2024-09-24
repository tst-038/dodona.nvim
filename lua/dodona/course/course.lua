local api = require("dodona.api")
local stringUtil = require("dodona.utils.string")
local notify = require("notify")

local M = {}

-- Fetch and return the list of subscribed courses
function M.getSubscribedCourses()
	local result = api.get("", false)

	if not result or not result.body then
		notify("Failed to fetch data from the server", "error")
		return {}
	end

	if not result.body.user then
		notify("User data is missing in the response", "error")
		return {}
	end

	return result.body.user.subscribed_courses or {}
end

-- Get details of a specific course using its name, id, or year
function M.getCourse(name, id, year)
	local courses = M.getSubscribedCourses()

	if #courses == 0 then
		notify("No subscribed courses found", "error")
		return nil
	end

	for _, course in ipairs(courses) do
		if course.name == name or course.id == id or course.year == year then
			return course
		end
	end

	notify("Course not found", "warn")
	return nil
end

-- Helper to fetch courses, including pagination
local function fetchCourses(page, filter)
	local params = {
		can_register = "true",
		tab = "all",
		filter = filter:gsub(" ", "+"),
		page = page,
	}
	local response = api.get("/courses/", false, params)
	if response and response.body then
		return response.body or {}
	end
	return {}
end

-- Function to check if a course is subscribed by comparing the course id
function M.isCourseSubscribed(course_id, subscribed_courses)
	for _, course in ipairs(subscribed_courses) do
		if course.id == course_id then
			return true
		end
	end
	return false
end

-- Function to get the Nerd Font symbol for subscription status
local function getSubscriptionSymbol(course_id, subscribed_courses)
	return require("dodona.utils.icon").get_subscribed_icon(course_id, subscribed_courses)
end

function M.getCoursesFinder()
	local function get_courses(prompt)
		local courses = fetchCourses(1, prompt)
		local filtered_courses = {}
		local cached_subscribed_courses = M.getSubscribedCourses()

		for _, course in ipairs(courses) do
			if course.name and course.name:find(prompt) then
				local name_width = 60
				local year_width = 20
				local teacher_width = 10

				local display_str = stringUtil.pad_string(course.name, name_width)
					.. stringUtil.pad_string(course.year or "", year_width)
					.. stringUtil.pad_string(course.teacher or "", teacher_width)

				table.insert(filtered_courses, {
					display = string.format(
						"%s %s",
						getSubscriptionSymbol(course.id, cached_subscribed_courses),
						display_str
					),
					ordinal = course.name,
					course_id = course.id,
					series = course.series,
					teacher = course.teacher,
					url = course.url,
					year = course.year,
				})
			end
		end
		return filtered_courses
	end

	return get_courses
end

-- Toggle subscription status
function M.toggleSubscription(entry, subscribed_courses)
	local course_id = entry.course_id
	if M.isCourseSubscribed(course_id, subscribed_courses or M.getSubscribedCourses()) then
		notify(
			"You are already subscribed to course: \n"
				.. entry.ordinal
				.. " "
				.. entry.year
				.. "\nTo unsubsribe visit\n"
				.. entry.url:match("(.*)%.json$"),
			"warn"
		)
	else
		api.get("/courses/" .. course_id .. "/subscribe", false, {})
		notify("Subscribed to course: " .. entry.ordinal .. " " .. entry.year .. " " .. entry.teacher, "info")
	end
end

-- Inspect course, opening series view
function M.inspectCourse(course)
	require("dodona.pickers.serie_picker").serieSelector(course)
end

return M
