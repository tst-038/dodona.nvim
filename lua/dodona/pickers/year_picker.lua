local manager = require("dodona.manager")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local picker_helper = require("dodona.utils.picker_helper")
local notify = require("dodona.notify")
local M = {}

function M.yearSelector()
	local progress = notify.progress("Fetching subscribed courses…")
	return manager.getSubscribedCoursesAsync(function(err, courses)
		if err then
			progress:finish(err.message, "error")
			return
		end
		progress:finish("Subscribed courses loaded")
		local years = {}

		for _, course in ipairs(courses) do
			if course.year then
				years[course.year] = true
			end
		end

		local unique_years = vim.tbl_keys(years)

		table.sort(unique_years, function(a, b)
			local a_start_year = tonumber(a:match("^(%d%d%d%d)")) or 0
			local b_start_year = tonumber(b:match("^(%d%d%d%d)")) or 0
			return a_start_year > b_start_year
		end)
		picker_helper.create_picker({}, unique_years, nil, "Select Year", function(prompt_bufnr, map)
		map("i", "<CR>", function()
			local selection = action_state.get_selected_entry()
			actions.close(prompt_bufnr)
			if selection then
				require("dodona.pickers.course_picker").courseSelector(selection.value, courses)
			end
		end)
		return true
		end)
	end)
end

return M
