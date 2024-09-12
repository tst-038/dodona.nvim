local api = require("dodona.api") -- Assuming your API module is named 'dodona.api'
local telescope = require("telescope")
local actions = require("telescope.actions")

local M = {}

-- Fetch and return the list of subscribed courses
function M.getSubscribedCourses()
	local result = api.get("", false)
	return result.body.user.subscribed_courses
end

-- Get details of a specific course using its name, id, or year
function M.getCourse(name, id, year)
	local courses = M.getSubscribedCourses()
	for _, course in ipairs(courses) do
		if course.name == name or course.id == id or course.year == year then
			return course
		end
	end
	return nil
end

-- Get the series available in a course
function M.getSeries(course_id)
	local result = api.get("/courses/" .. course_id .. "/series")
	return result.body
end

-- Get the activities in a series
function M.getActivities(serie_id)
	local result = api.get("/series/" .. serie_id .. "/activities")
	return result.body
end

-- Subscribe to a course using its ID
function M.subscribe(course_id)
	local result = api.post("/courses/" .. course_id .. "/subscribe", {})
	return result.body
end

-- Evaluate submission for an activity (assuming evaluation submission)
function M.evalSubmission(submission_id)
	local result = api.post("/submissions/" .. submission_id .. "/evaluate", {})
	return result.body
end

-- Enhanced download data function with media search
function M.downloadData(url)
	local result = api.get(url, true) -- Using full URL
	if result.status == 200 then
		local media_files = result.body -- Assuming body contains media file data

		-- Use Telescope to allow the user to select media to download
		telescope.pickers
			.new({}, {
				prompt_title = "Select Media to Download",
				finder = telescope.finders.new_table({
					results = media_files,
					entry_maker = function(file)
						return {
							value = file.url,
							display = file.name,
							ordinal = file.name,
						}
					end,
				}),
				sorter = telescope.config.sorters.get_generic_fuzzy_sorter(),
				attach_mappings = function(_, map)
					map("i", "<CR>", function(_, entry)
						-- On Enter, download the selected media file
						local download_url = entry.value
						local download_result = api.get(download_url, true)
						if download_result.status == 200 then
							vim.notify("Successfully downloaded: " .. entry.display)
						else
							vim.notify("Failed to download: " .. entry.display)
						end
					end)
					return true
				end,
			})
			:find()
	else
		vim.notify("Failed to fetch media files from: " .. url)
	end
end

return M
