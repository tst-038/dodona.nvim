local api = require("dodona.api")
local stringUtil = require("dodona.utils.string")
local notify = require("dodona.notify")
local cache = require("dodona.cache")

local M = {}

-- Fetch and return the list of subscribed courses
function M.getSubscribedCourses()
	local cached = cache.get("courses:subscribed")
	if cached then
		return cached
	end
	local result = api.get("", false)

	if not result or not result.body then
		notify("Failed to fetch data from the server", "error")
		return {}
	end

	if not result.body.user then
		notify("User data is missing in the response", "error")
		return {}
	end

	local courses = result.body.user.subscribed_courses or {}
	cache.set("courses:subscribed", courses)
	return courses
end

function M.getSubscribedCoursesAsync(callback)
	return cache.fetch("courses:subscribed", function(done)
		api.get_async("", {}, function(err, result)
			if err then
				done(err, {})
				return
			end
			local user = result.body and result.body.user
			if not user then
				done({ message = "User data is missing in the Dodona response" }, {})
				return
			end
			done(nil, user.subscribed_courses or {})
		end)
		end, callback)
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

local function transform_courses(courses, subscribed_courses)
	local transformed = {}
	for _, course in ipairs(courses) do
		local display_str = stringUtil.pad_string(course.name or "", 60)
			.. stringUtil.pad_string(course.year or "", 20)
			.. stringUtil.pad_string(course.teacher or "", 10)
		table.insert(transformed, {
			display = string.format("%s %s", getSubscriptionSymbol(course.id, subscribed_courses), display_str),
			ordinal = course.name,
			course_id = course.id,
			series = course.series,
			teacher = course.teacher,
			url = course.url,
			year = course.year,
			course = course,
		})
	end
	return transformed
end

function M.getCoursesFinder()
	local function get_courses(prompt)
		local courses = fetchCourses(1, prompt)
		local filtered_courses = {}
		local cached_subscribed_courses = M.getSubscribedCourses()
		filtered_courses = transform_courses(courses, cached_subscribed_courses)
		return filtered_courses
	end

	return get_courses
end

function M.searchCoursesAsync(prompt, callback)
	local params = { can_register = "true", tab = "all", filter = prompt, page = 1 }
	return api.get_async("/courses/", { params = params }, function(err, response)
		if err then
			callback(err, {})
			return
		end
		M.getSubscribedCoursesAsync(function(subscribed_err, subscribed)
			if subscribed_err then
				callback(subscribed_err, {})
				return
			end
			callback(nil, transform_courses(response.body or {}, subscribed))
		end)
	end)
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
		cache.invalidate("courses:")
		notify("Subscribed to course: " .. entry.ordinal .. " " .. entry.year .. " " .. entry.teacher, "info")
	end
end

-- Inspect course, opening series view
function M.inspectCourse(course)
	if type(course) ~= "table" then
		notify("Could not open course: invalid selection", "error")
		return
	end
	require("dodona.pickers.serie_picker").serieSelector(course)
end

return M
