local manager = require("dodona.manager")
local api = require("dodona.api")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")

local M = {}

-- Previewer for activities or media content
local file_previewer = previewers.new_buffer_previewer({
	preview_title = "Latest submission",
	define_preview = function(self, entry)
		local submissions = api.get(
			"/courses/" .. entry.course .. "/series/" .. entry.serie .. "/activities/" .. entry.value .. "/submissions",
			false
		)
		local content_to_show = ""

		if submissions and #submissions.body > 0 then
			local latest_submission_url = submissions.body[1].url

			local latest_submission = api.get(latest_submission_url, true)

			if latest_submission and latest_submission.body.code then
				content_to_show = latest_submission.body.code
			end
		end

		local response =
			api.get("/courses/" .. entry.course .. "/series/" .. entry.serie .. "/activities/" .. entry.value, false)
		local filetype = response.body.programming_language.extension
		if content_to_show == "" then
			content_to_show = response.body.boilerplate
		end

		vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(content_to_show, "\n"))

		vim.api.nvim_buf_call(self.state.bufnr, function()
			vim.cmd("setfiletype " .. filetype)
		end)
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
				map("i", "<CR>", function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					M.courseSelector(selection.value)
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
					actions.close(prompt_bufnr)
					M.serieSelector(selection.value)
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
					actions.close(prompt_bufnr)
					M.activitySelector(selection.course, selection.value)
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
			preview_title = "Latest Submission",
			sorter = sorters.get_generic_fuzzy_sorter(),
			attach_mappings = function(_, map)
				map("i", "<CR>", function(_, entry)
					vim.notify("Selected activity: " .. entry.display)
				end)
				return true
			end,
		})
		:find()
end

-- Helper to preview the media file using a buffer
local media_previewer = previewers.new_buffer_previewer({
	define_preview = function(self, entry)
		manager.downloadToBuffer(entry.base_url, entry.value, function(buf)
			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
		end)

		print(vim.inspect(entry.display))

		vim.api.nvim_buf_call(self.state.bufnr, function()
			vim.cmd("setfiletype " .. entry.display:match("^.+%.([^%.]+)$"))
		end)
	end,
})

-- Media Selector using Telescope
function M.downloadMediaSelector(url)
	local media_files = manager.getMediaFiles(url)

	if #media_files == 0 then
		vim.notify("No media files found", "warn")
		return
	end

	pickers
		.new({}, {
			prompt_title = "Select Media to Download",
			finder = finders.new_table({
				results = media_files,
				entry_maker = function(file)
					return {
						value = file.url,
						display = file.name,
						ordinal = file.name,
						base_url = file.base_url,
					}
				end,
			}),
			sorter = sorters.get_generic_fuzzy_sorter(),
			previewer = media_previewer,
			attach_mappings = function(prompt_bufnr, map)
				map("i", "<CR>", function()
					local entry = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					manager.downloadToBuffer(entry.base_url, entry.value, function(buf)
						local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
						vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

						vim.notify("File content copied to the current buffer: " .. entry.display, "info")
					end)
				end)
				return true
			end,
		})
		:find()
end

return M
