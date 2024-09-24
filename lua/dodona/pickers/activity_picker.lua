local manager = require("dodona.manager")
local api = require("dodona.api")
local icon = require("dodona.utils.icon")
local string_utils = require("dodona.utils.string")
local picker_helper = require("dodona.utils.picker_helper")
local media_picker = require("dodona.pickers.media_picker")
local action_state = require("telescope.actions.state")
local file_ops = require("dodona.utils.file_operations")
local actions = require("telescope.actions")

local M = {}

local function transform_activity(activity, index, course, serie)
	return {
		index = index,
		course = course,
		serie = serie,
		value = activity.id,
		display = icon.get_icon(activity.programming_language.name) .. icon.get_status_icon(activity) .. activity.name,
		ordinal = activity.name,
		url = activity.url:gsub("%.json$", "/"),
		extension = activity.programming_language.extension,
		programming_language = activity.programming_language.name,
		comment = require("dodona.comments")[activity.programming_language.name],
		preview_content = activity.boilerplate,
		has_solution = activity.has_solution,
		has_correct_solution = activity.has_correct_solution,
		last_solution_is_best = activity.last_solution_is_best,
		boilerplate = activity.boilerplate,
	}
end

function M.prepare_activities(course, serie)
	local activities = manager.getActivities(serie.id)
	local filtered_activities = {}
	local transformed_activities = {}

	for _, activity in ipairs(activities) do
		if activity.type == "Exercise" then
			table.insert(filtered_activities, activity)
		end
	end

	table.insert(transformed_activities, {
		course = course,
		serie = serie,
		value = "all",
		display = icon.get_all_activities_icon() .. icon.get_status_icon({
			has_correct_solution = false,
			has_solution = false,
			last_solution_is_best = false,
		}) .. "All Activities",
		ordinal = "All Activities",
		preview_content = "",
		boilerplate = "",
		has_solution = false,
		last_solution_is_best = false,
		has_correct_solution = false,
	})

	for index, activity in ipairs(filtered_activities) do
		table.insert(transformed_activities, transform_activity(activity, index - 1, course, serie))
	end

	return transformed_activities
end

local function fetch_latest_submission(activity)
	local submissions = api.get(
		"/courses/"
		.. activity.course.id
		.. "/series/"
		.. activity.serie.id
		.. "/activities/"
		.. activity.value
		.. "/submissions",
		false
	)

	if submissions and #submissions.body > 0 then
		local latest_submission_url = submissions.body[1].url
		local latest_submission = api.get(latest_submission_url, true)

		if latest_submission and latest_submission.body.code and latest_submission.body.code ~= "" then
			activity.preview_content = latest_submission.body.code
		end
	end
	return activity
end

-- Function to handle downloading a single activity
local function download_activity(activity, length, activities, index)
	if activity.value ~= "all" then
		local file_name = activity.ordinal .. "." .. activity.extension
		if activity.preview_content == activity.boilerplate and activity.has_solution then
			fetch_latest_submission(activity)
		end
		local index_activity = (index and string_utils.pad_number(index, activities) .. "_" or "")
		local file_path = vim.fn.getcwd()
				.. "/"
				.. activity.course.year
				.. "/"
				.. activity.course.name:gsub(" ", "_")
				.. "_"
				.. activity.course.id
				.. "/"
				.. string_utils.pad_number(activity.serie.order, length)
				.. "_"
				.. file_ops.sanitize_filename(activity.serie.name:gsub(" ", "_"))
				.. "/"
				.. index_activity
				.. file_ops.sanitize_filename(file_name:gsub(" ", "_"))
				.. "/"
		local full_path = file_path .. file_ops.sanitize_filename(file_name:gsub(" ", "_"))
		file_ops.check_and_queue_file(activity, full_path)
		media_picker.download_all_media(media_picker.get_all_prepared_media(activity.url), file_path)
	end
end

-- Function to download all activities
function M.download_all_activities(transformed_activities, number_padding)
	if number_padding == nil then
		number_padding = 0
	end
	for index, activity in ipairs(transformed_activities) do
		if activity.value ~= "all" then
			download_activity(activity, number_padding, #tostring(#transformed_activities), index - 2)
		end
	end
end

function M.activitySelector(course, serie)
	local transformed_activities = M.prepare_activities(course, serie)

	picker_helper.create_picker(
		{
			previewer = require("dodona.previewers.file_previewer").file_previewer,
			preview_title = "Latest submission",
		},
		transformed_activities,
		function(entry)
			return entry
		end,
		"Select Activity",
		function(prompt_bufnr, map)
			map("i", "<CR>", function()
				actions.close(prompt_bufnr)

				local selection = action_state.get_selected_entry()
				if selection.value == "all" then
					M.download_all_activities(transformed_activities)
					file_ops.process_file_queue()
				else
					download_activity(selection, 0, #tostring(#transformed_activities))
					file_ops.process_file_queue()
				end
			end)

			return true
		end
	)
end

return M
