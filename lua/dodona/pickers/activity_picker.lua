local manager = require("dodona.manager")
local picker_helper = require("dodona.utils.picker_helper")
local action_state = require("telescope.actions.state")
local file_ops = require("dodona.utils.file_operations")

local M = {}

function M.activitySelector(course_id, serie_id)
	local activities = manager.getActivities(serie_id)

	picker_helper.create_picker(
		{
			previewer = require("dodona.previewers.file_previewer").file_previewer,
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
				comment = require("dodona.comments")[activity.programming_language.name],
				preview_content = activity.boilerplate,
			}
		end,
		"Select Activity",
		function(prompt_bufnr, map)
			map("i", "<CR>", function()
				local selection = action_state.get_selected_entry()
				local file_name = selection.display .. "." .. selection.extension

				file_ops.check_and_write_file(selection, file_name)
			end)
			return true
		end
	)
end

return M
