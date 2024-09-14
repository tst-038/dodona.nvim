local manager = require("dodona.manager")
local comments = require("dodona.comments")
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

local function write_to_file(entry, file_path)
	local file = io.open(file_path, "w")
	if file then
		-- Write comment and URL
		file:write(entry.comment .. " " .. entry.url .. "\n")

		-- Write the preview content if available
		if entry.preview_content and entry.preview_content ~= "" then
			print(vim.inspect(entry))
			file:write(entry.preview_content)
		end

		file:close()
		vim.notify("File written: " .. file_path, "info")
	else
		vim.notify("Error writing to file: " .. file_path, "error")
	end
end

-- Function to check if a file exists and prompt the user to override it
local function check_and_write_file(entry, file_name)
	local file_path = vim.fn.getcwd() .. "/" .. file_name

	-- Check if the file exists
	if vim.fn.filereadable(file_path) == 1 then
		-- Ask if the user wants to override the file
		vim.ui.select({ "Yes", "No" }, {
			prompt = "File already exists! Do you want to override it?",
		}, function(choice)
			if choice == "Yes" then
				write_to_file(entry, file_path)
			else
				vim.notify("File not overwritten: " .. file_name, "info")
			end
		end)
	else
		-- If file doesn't exist, write directly
		write_to_file(entry, file_path)
	end
end

-- Previewer for activities or media content
local file_previewer = previewers.new_buffer_previewer({
	preview_title = "Latest submission",
	define_preview = function(self, entry)
		local submissions = api.get(
			"/courses/" .. entry.course .. "/series/" .. entry.serie .. "/activities/" .. entry.value .. "/submissions",
			false
		)

		if submissions and #submissions.body > 0 then
			local latest_submission_url = submissions.body[1].url
			local latest_submission = api.get(latest_submission_url, true)

			if latest_submission and latest_submission.body.code and latest_submission.body.code ~= "" then
				entry.preview_content = latest_submission.body.code
			end
		end
		set_buffer_content(self.state.bufnr, entry.preview_content, entry.extension)
	end,
})

-- Selector for activities
function M.activitySelector(course_id, serie_id)
	local activities = manager.getActivities(serie_id)

	create_picker(
		{
			previewer = file_previewer,
			preview_title = "Latest submission",
		},
		activities,
		function(activity)
			return {
				course = course_id,
				serie = serie_id,
				value = activity.id,
				display = activity.name,
				ordinal = activity.name,
				url = activity.url:gsub("%.json$", "/"),
				extension = activity.programming_language.extension,
				programming_language = activity.programming_language.name,
				comment = comments[activity.programming_language.name], -- Comment field for the language
				preview_content = activity.boilerplate,
			}
		end,
		"Select Activity",
		function(_, map)
			map("i", "<CR>", function(_, entry)
				local selection = action_state.get_selected_entry()
				local file_name = selection.display .. "." .. selection.extension

				-- Check if the file exists and handle writing it
				check_and_write_file(selection, file_name)
			end)
			return true
		end
	)
end

-- Previewer for media content
local media_previewer = previewers.new_buffer_previewer({
	define_preview = function(self, entry)
		-- Download the content to a temporary buffer
		manager.downloadToBuffer(entry.base_url, entry.value, function(buf)
			-- Get the content from the buffer and store it in entry.preview_content
			entry.preview_content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")

			-- Use the helper function to set the content and filetype
			set_buffer_content(self.state.bufnr, entry.preview_content, entry.display:match("^.+%.([^%.]+)$"))
		end)
	end,
})

-- Media Selector using Telescope
function M.downloadMediaSelector()
	local bufnr = vim.api.nvim_get_current_buf()
	local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
	local url = first_line:match("(https?://[%w-_%.%?%.:/%+=&]+)") or ""
	url = url:gsub("/$", "")

	if url ~= "" then
		local api_response = api.get(url, true)

		if api_response and api_response.body then
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
						-- Initialize content as empty, will be updated in the preview
						preview_content = "",
					}
				end,
				"Select Media to Download",
				function(prompt_bufnr, map)
					map("i", "<CR>", function()
						local entry = action_state.get_selected_entry()

						if not entry then
							vim.notify("No valid selection", "error")
							return
						end

						-- Use the content stored in the entry itself
						local content_to_write = entry.preview_content or ""

						-- Define file path
						local filepath = vim.fn.getcwd() .. "/" .. entry.display

						local function write_to_file()
							local f = io.open(filepath, "w")
							if f then
								f:write(content_to_write)
								f:close()
								vim.notify("File written: " .. filepath, "info")
							else
								vim.notify("Failed to open file: " .. filepath, "error")
							end
						end

						-- Check if file exists and prompt for confirmation
						if vim.fn.filereadable(filepath) == 1 then
							vim.ui.select({ "Yes", "No" }, {
								prompt = "File already exists! Do you want to override it?",
							}, function(choice)
								if choice == "Yes" then
									write_to_file()
								else
									vim.notify("File not overwritten: " .. filepath, "info")
								end
							end)
						else
							-- If file doesn't exist, write to the file directly
							write_to_file()
						end

						-- Close the picker window
						actions.close(prompt_bufnr)
					end)
					return true
				end
			)
			return
		else
			vim.notify("First line does not return a valid API request", "warn")
		end
	end

	vim.notify("Falling back to course selection", "info")
	M.yearSelector()
end

return M
