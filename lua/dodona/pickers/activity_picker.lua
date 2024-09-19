local manager = require("dodona.manager")
local api = require("dodona.api")
local icon = require("dodona.utils.icon")
local picker_helper = require("dodona.utils.picker_helper")
local action_state = require("telescope.actions.state")
local file_ops = require("dodona.utils.file_operations")
local actions = require("telescope.actions")

local M = {}

local function transform_activity(activity, course_id, serie_id)
	return {
		course = course_id,
		serie = serie_id,
		value = activity.id,
		display = icon.get_icon(activity.programming_language.name) .. activity.name,
		ordinal = activity.name,
		url = activity.url:gsub("%.json$", "/"),
		extension = activity.programming_language.extension,
		programming_language = activity.programming_language.name,
		comment = require("dodona.comments")[activity.programming_language.name],
		preview_content = activity.boilerplate,
	}
end

local function prepare_activities(course_id, serie_id)
	local activities = manager.getActivities(serie_id)
	local transformed_activities = {}

	table.insert(transformed_activities, {
		course = course_id,
		serie = serie_id,
		value = "all",
		display = "📥 All Activities",
		ordinal = "All Activities",
		preview_content = "",
	})

	for _, activity in ipairs(activities) do
		table.insert(transformed_activities, transform_activity(activity, course_id, serie_id))
	end

	return transformed_activities
end

local function fetch_latest_submission(activity)
	local submissions = api.get(
		"/courses/"
		.. activity.course_id
		.. "/series/"
		.. activity.serie_id
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
local function download_activity(activity)
	if activity.value ~= "all" then
		local file_name = activity.ordinal .. "." .. activity.extension
		if not activity.preview_content then
			fetch_latest_submission(activity)
		end
		local file_path = vim.fn.getcwd() .. "/" .. file_name
		file_ops.check_and_write_file(activity, file_path)
	end
end

-- Function to download all activities
local function download_all_activities(transformed_activities)
	for _, activity in ipairs(transformed_activities) do
		if activity.value ~= "all" then
			download_activity(activity)
		end
	end
end

function M.activitySelector(course_id, serie_id)
	local transformed_activities = prepare_activities(course_id, serie_id)

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
				local selection = action_state.get_selected_entry()

				if selection.value == "all" then
					download_all_activities(transformed_activities)
				else
					download_activity(selection)
				end

				actions.close(prompt_bufnr)
			end)

			return true
		end
	)
end

return M
