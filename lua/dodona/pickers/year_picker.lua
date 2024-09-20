local manager = require("dodona.manager")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local picker_helper = require("dodona.utils.picker_helper")
local M = {}

function M.yearSelector()
	local courses = manager.getSubscribedCourses()
	local years = {}

	for _, course in ipairs(courses) do
		years[course.year] = true
	end

	local unique_years = vim.tbl_keys(years)

	table.sort(unique_years, function(a, b)
		local a_start_year = tonumber(a:match("^(%d%d%d%d)"))
		local b_start_year = tonumber(b:match("^(%d%d%d%d)"))
		return a_start_year > b_start_year
	end)
	picker_helper.create_picker({}, unique_years, nil, "Select Year", function(prompt_bufnr, map)
		map("i", "<CR>", function()
			local selection = action_state.get_selected_entry()
			actions.close(prompt_bufnr)
			require("dodona.pickers.course_picker").courseSelector(selection.value)
		end)
		return true
	end)
end

return M
