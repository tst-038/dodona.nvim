local manager = require("dodona.manager")
local api = require("dodona.api")
local telescope = require("telescope.builtin") -- Use built-in telescope functions
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")

local M = {}

-- Previewer for activities or media content
local file_previewer = previewers.new_buffer_previewer({
	define_preview = function(self, entry)
		local file_content =
			api.get("/courses/" .. entry.course .. "/series/" .. entry.serie .. "/activities/" .. entry.value, false) -- Assuming file content is returned in body
		vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(file_content.body.boilerplate, "\n"))
	end,
})

-- Selector for course years
function M.yearSelector()
	local courses = manager.getSubscribedCourses()
	local years = {}

	for _, course in ipairs(courses) do
		years[course.year] = true
	end

	local unique_years = vim.tbl_keys(years)

	pickers
		.new({}, {
			prompt_title = "Select Year",
			finder = finders.new_table({
				results = unique_years,
			}),
			sorter = sorters.get_generic_fuzzy_sorter(),
			attach_mappings = function(prompt_bufnr, map)
				-- Use entry.value to access the selected year
				map("i", "<CR>", function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr) -- Close Telescope picker
					M.courseSelector(selection.value) -- Pass the selected year to courseSelector
				end)
				return true
			end,
		})
		:find()
end

-- Selector for courses
function M.courseSelector(selected_year)
	local courses = manager.getSubscribedCourses()
	local filtered_courses = {}

	for _, course in ipairs(courses) do
		if course.year == selected_year then
			table.insert(filtered_courses, course)
		end
	end

	pickers
		.new({}, {
			prompt_title = "Select Course",
			finder = finders.new_table({
				results = filtered_courses,
				entry_maker = function(course)
					return {
						value = course.id,
						display = course.name,
						ordinal = course.name,
					}
				end,
			}),
			sorter = sorters.get_generic_fuzzy_sorter(),
			attach_mappings = function(prompt_bufnr, map)
				map("i", "<CR>", function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr) -- Close Telescope picker
					M.serieSelector(selection.value) -- Pass the selected year to courseSelector
				end)
				return true
			end,
		})
		:find()
end

-- Selector for series
function M.serieSelector(course_id)
	local series = manager.getSeries(course_id)

	pickers
		.new({}, {
			prompt_title = "Select Series",
			finder = finders.new_table({
				results = series,
				entry_maker = function(serie)
					return {
						course = course_id,
						value = serie.id,
						display = serie.name,
						ordinal = serie.name,
					}
				end,
			}),
			sorter = sorters.get_generic_fuzzy_sorter(),
			attach_mappings = function(prompt_bufnr, map)
				map("i", "<CR>", function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr) -- Close Telescope picker
					M.activitySelector(selection.course, selection.value) -- Pass the selected year to courseSelector
				end)
				return true
			end,
		})
		:find()
end

-- Selector for activities
function M.activitySelector(course_id, serie_id)
	local activities = manager.getActivities(serie_id)

	pickers
		.new({}, {
			prompt_title = "Select Activity",
			finder = finders.new_table({
				results = activities,
				entry_maker = function(activity)
					return {
						course = course_id,
						serie = serie_id,
						value = activity.id,
						display = activity.name,
						ordinal = activity.name,
					}
				end,
			}),
			previewer = file_previewer,
			sorter = sorters.get_generic_fuzzy_sorter(),
			attach_mappings = function(_, map)
				map("i", "<CR>", function(_, entry)
					-- You can handle activity selection here
					vim.notify("Selected activity: " .. entry.display)
				end)
				return true
			end,
		})
		:find()
end

-- Download Selector for media
function M.downloadSelector()
	local course_id = 123 -- This would come from your course selection logic
	local media_url = "/courses/" .. course_id .. "/media"

	-- Call the downloadData function to display available media and allow selection
	manager.downloadData(media_url)
end

return M
