local api = require("dodona.api")
local Job = require("plenary.job")
local utils = require("dodona.utils")

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

-- Get the series available in a course
function M.getSeries(course_id)
	local result = api.get("/courses/" .. course_id .. "/series")

	if not result or result.status ~= 200 then
		vim.notify("Failed to fetch series for course ID: " .. course_id, "error")
		return {}
	end

	return result.body or {}
end

-- Get the activities in a series
function M.getActivities(serie_id)
	local result = api.get("/series/" .. serie_id .. "/activities")

	if not result or result.status ~= 200 then
		vim.notify("Failed to fetch activities for series ID: " .. serie_id, "error")
		return {}
	end

	return result.body or {}
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

-- Evaluate submission for an activity (assuming evaluation submission)
function M.evalSubmission(submission_id)
	local result = api.post("/submissions/" .. submission_id .. "/evaluate", {})

	if not result or result.status ~= 200 then
		vim.notify("Failed to evaluate submission ID: " .. submission_id, "error")
		return {}
	end

	return result.body or {}
end

-- Function to get media files from the API
function M.getMediaFiles(url)
	local response = api.get(url .. ".json", true)

	if response.status ~= 200 then
		vim.notify("Failed to fetch media metadata from: " .. url, "error")
		return {}
	end

	local description = api.gethtml(response.body.description_url).body
	local handled = {}
	local media_files = {}

	for w in string.gmatch(description, '"media/.-"') do
		local clean_url = w:gsub('^"', ""):gsub('"$', "")
		if
			not utils.has_value(handled, clean_url)
			and not clean_url:find(".png")
			and not clean_url:find(".jpg")
			and not clean_url:find(".zip")
		then
			table.insert(media_files, {
				url = clean_url,
				name = string.sub(clean_url, clean_url:find("/[^/]*$") + 1),
				base_url = response.body.description_url,
			})
			table.insert(handled, clean_url)
		end
	end

	print(vim.inspect(media_files))

	return media_files
end

-- Function to download a file using wget and load it into a buffer for preview or copy
function M.downloadToBuffer(base_url, w, callback)
	local temp_file = vim.fn.tempname()
	Job:new({
		command = "wget",
		args = { base_url .. w, "-O", temp_file },
		on_exit = function(_, return_val)
			if return_val == 0 then
				vim.schedule(function()
					local buf = vim.api.nvim_create_buf(false, true)
					vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.fn.readfile(temp_file))

					if callback then
						callback(buf)
					end
				end)
			else
				vim.schedule(function()
					vim.notify("Error when downloading: " .. string.sub(w, w:find("/[^/]*$") + 1, -1), "error")
				end)
			end
		end,
	}):start()
end

return M
