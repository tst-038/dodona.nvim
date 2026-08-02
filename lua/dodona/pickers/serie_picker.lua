local manager = require("dodona.manager")
local picker_helper = require("dodona.utils.picker_helper")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local icon = require("dodona.utils.icon")
local notify = require("dodona.notify")

local M = {}

local function download_all_series_activities(course, series)
	local activity_picker = require("dodona.pickers.activity_picker")
	local current = 0
	local progress = notify.progress(string.format("Preparing 0/%d series…", #series))
	local function next_series()
		current = current + 1
		local serie = series[current]
		if not serie then
			progress:finish("All series downloaded")
			return
		end
		progress:update(string.format("Preparing %d/%d series: %s", current, #series, serie.name))
		manager.getActivitiesAsync(serie.id, function(err, activities)
			if err then
				progress:finish(err.message, "error")
				return
			end
			local transformed = activity_picker.transform_activities(course, serie, activities)
			activity_picker.download_all_activities(transformed, #tostring(#series), next_series)
		end)
	end
	next_series()
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
	local progress = notify.progress("Fetching series for " .. course.name .. "…")
	return manager.getSeriesAsync(course.id, function(err, series)
		if err then
			progress:finish(err.message, "error")
			return
		end
		progress:finish("Series loaded")
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
				else
					actions.close(prompt_bufnr)
					require("dodona.pickers.activity_picker").activitySelector(selection.course, selection.serie)
				end
			end)
			return true
		end
		)
	end)
end

return M
