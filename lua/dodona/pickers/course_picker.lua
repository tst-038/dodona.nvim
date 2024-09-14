local manager = require("dodona.manager")
local picker_helper = require("dodona.utils.picker_helper")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

function M.courseSelector(selected_year)
	local courses = manager.getSubscribedCourses()
	local filtered_courses = vim.tbl_filter(function(course)
		return course.year == selected_year
	end, courses)

	picker_helper.create_picker(
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
				require("dodona.pickers.serie_picker").serieSelector(selection.value)
			end)
			return true
		end
	)
end

return M
