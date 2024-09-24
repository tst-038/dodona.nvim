local manager = require("dodona.manager")
local picker_helper = require("dodona.utils.picker_helper")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local icon = require("dodona.utils.icon")
local file_operations = require("dodona.utils.file_operations")

local M = {}

local function download_all_series_activities(course, series)
	for _, serie in ipairs(series) do
		local transformed_activities = require("dodona.pickers.activity_picker").prepare_activities(course, serie)
		require("dodona.pickers.activity_picker").download_all_activities(transformed_activities, #tostring(#series))
	end
	file_operations.process_file_queue()
end

local function transform_all_series_entry(course, series)
	local transformed_series = {}
	for _, serie in ipairs(series) do
		table.insert(transformed_series, {
			course = course,
			value = serie.id,
			display = serie.name,
			ordinal = serie.name,
			serie = serie,
		})
	end
	return transformed_series
end

function M.serieSelector(course)
	local series = manager.getSeries(course.id)
	local transformed_series = transform_all_series_entry(course, series)

	table.insert(transformed_series, 1, {
		course = course,
		value = "all",
		display = icon.get_all_series_icon() .. "All Series",
		ordinal = "All Series",
	})

	picker_helper.create_picker(
		{},
		transformed_series,
		function(entry)
			return entry
		end,
		"Select Series",
		function(prompt_bufnr, map)
			map("i", "<CR>", function()
				local selection = action_state.get_selected_entry()

				if selection.value == "all" then
					actions.close(prompt_bufnr)
					download_all_series_activities(course, series)
					file_operations.process_file_queue()
				else
					actions.close(prompt_bufnr)
					require("dodona.pickers.activity_picker").activitySelector(selection.course, selection.serie)
				end
			end)
			return true
		end
	)
end

return M
