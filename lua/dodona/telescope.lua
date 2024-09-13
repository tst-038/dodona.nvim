local manager = require("dodona.manager")
local api = require("dodona.api")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")

local M = {}

-- Helper function to create a picker
local function create_picker(opts, results, entry_maker, prompt_title, mappings)
	pickers
			.new(opts, {
				prompt_title = prompt_title,
				finder = finders.new_table({
					results = results,
					entry_maker = entry_maker,
				}),
				sorter = sorters.get_generic_fuzzy_sorter(),
				attach_mappings = mappings,
			})
			:find()
end

-- Helper function to set buffer content
local function set_buffer_content(bufnr, content, filetype)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))
	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd("setfiletype " .. filetype)
	end)
end

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
			content_to_show = latest_submission and latest_submission.body.code or ""
		end

		local response =
				api.get("/courses/" .. entry.course .. "/series/" .. entry.serie .. "/activities/" .. entry.value, false)
		local filetype = response.body.programming_language.extension
		content_to_show = content_to_show == "" and response.body.boilerplate or content_to_show

		set_buffer_content(self.state.bufnr, content_to_show, filetype)
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
	create_picker({}, unique_years, nil, "Select Year", function(prompt_bufnr, map)
		map("i", "<CR>", function()
			local selection = action_state.get_selected_entry()
			actions.close(prompt_bufnr)
			M.courseSelector(selection.value)
		end)
		return true
	end)
end

-- Selector for courses
function M.courseSelector(selected_year)
	local courses = manager.getSubscribedCourses()
	local filtered_courses = vim.tbl_filter(function(course)
		return course.year == selected_year
	end, courses)

	create_picker(
		{},
		filtered_courses,
		function(course)
			return {
				value = course.id,
				display = course.name,
				ordinal = course.name,
			}
		end,
		"Select Course",
		function(prompt_bufnr, map)
			map("i", "<CR>", function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				M.serieSelector(selection.value)
			end)
			return true
		end
	)
end

-- Selector for series
function M.serieSelector(course_id)
	local series = manager.getSeries(course_id)

	create_picker(
		{},
		series,
		function(serie)
			return {
				course = course_id,
				value = serie.id,
				display = serie.name,
				ordinal = serie.name,
			}
		end,
		"Select Series",
		function(prompt_bufnr, map)
			map("i", "<CR>", function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				M.activitySelector(selection.course, selection.value)
			end)
			return true
		end
	)
end

-- Selector for activities
function M.activitySelector(course_id, serie_id)
	local activities = manager.getActivities(serie_id)

	create_picker(
		{
			previewer = file_previewer,
		},
		activities,
		function(activity)
			return {
				course = course_id,
				serie = serie_id,
				value = activity.id,
				display = activity.name,
				ordinal = activity.name,
			}
		end,
		"Select Activity",
		function(_, map)
			map("i", "<CR>", function(_, entry)
				vim.notify("Selected activity: " .. entry.display)
			end)
			return true
		end
	)
end

-- Helper to preview the media file using a buffer
local media_previewer = previewers.new_buffer_previewer({
	define_preview = function(self, entry)
		manager.downloadToBuffer(entry.base_url, entry.value, function(buf)
			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
		end)

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

	create_picker(
		{
			previewer = media_previewer,
		},
		media_files,
		function(file)
			return {
				value = file.url,
				display = file.name,
				ordinal = file.name,
				base_url = file.base_url,
			}
		end,
		"Select Media to Download",
		function(prompt_bufnr, map)
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
		end
	)
end

return M
