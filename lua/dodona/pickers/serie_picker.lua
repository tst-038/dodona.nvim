local manager = require("dodona.manager")
local picker_helper = require("dodona.utils.picker_helper")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

function M.serieSelector(course_id)
	local series = manager.getSeries(course_id)

	picker_helper.create_picker(
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
				require("dodona.pickers.activity_picker").activitySelector(selection.course, selection.value)
			end)
			return true
		end
	)
end

return M
