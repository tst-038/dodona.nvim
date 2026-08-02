local manager = require("dodona.manager")
local api = require("dodona.api")
local icon = require("dodona.utils.icon")
local string_utils = require("dodona.utils.string")
local picker_helper = require("dodona.utils.picker_helper")
local media_picker = require("dodona.pickers.media_picker")
local action_state = require("telescope.actions.state")
local file_ops = require("dodona.utils.file_operations")
local actions = require("telescope.actions")
local notify = require("dodona.notify")
local config = require("dodona.config")

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

function M.transform_activities(course, serie, activities)
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

function M.prepare_activities(course, serie)
	return M.transform_activities(course, serie, manager.getActivities(serie.id))
end

local function fetch_latest_submission(activity, callback)
	local path = string.format(
		"/courses/%s/series/%s/activities/%s/submissions",
		activity.course.id,
		activity.serie.id,
		activity.value
	)
	return api.get_async(path, {}, function(err, submissions)
		local latest = not err and submissions.body and submissions.body[1]
		if not latest or not latest.url then
			callback(activity)
			return
		end
		api.get_async(latest.url, { full_url = true }, function(latest_err, response)
			if not latest_err and response.body and response.body.code and response.body.code ~= "" then
				activity.preview_content = response.body.code
			end
			callback(activity)
		end)
	end)
end

local function activity_paths(activity, series_padding, activity_padding, index)
	local file_name = file_ops.sanitize_filename((activity.ordinal .. "." .. activity.extension):gsub(" ", "_"))
	local series_number = series_padding > 0 and string_utils.pad_number(activity.serie.order, series_padding)
		or tostring(activity.serie.order)
	local activity_number = index and (string_utils.pad_number(index, activity_padding) .. "_") or ""
	local directory = table.concat({
		vim.fn.getcwd(),
		tostring(activity.course.year),
		file_ops.sanitize_filename(activity.course.name:gsub(" ", "_")) .. "_" .. activity.course.id,
		series_number .. "_" .. file_ops.sanitize_filename(activity.serie.name:gsub(" ", "_")),
		activity_number .. file_name,
	}, "/") .. "/"
	return directory, directory .. file_name
end

local function download_activity(activity, series_padding, activity_padding, index, callback)
	callback = callback or function() end
	local directory, full_path = activity_paths(activity, series_padding or 0, activity_padding, index)
	local function write_and_download_media()
		file_ops.check_and_queue_file(activity, full_path)
		if not config.get().download_on_init then
			callback()
			return
		end
		manager.getMediaFilesAsync(activity.url, function(err, files)
			if err or #files == 0 then
				callback(err)
				return
			end
			media_picker.download_all_media(media_picker.prepare_media(files), directory, callback)
		end)
	end
	if activity.preview_content == activity.boilerplate and activity.has_solution then
		fetch_latest_submission(activity, write_and_download_media)
	else
		write_and_download_media()
	end
end

function M.download_all_activities(transformed_activities, series_padding, callback)
	callback = callback or function() end
	local activities = vim.tbl_filter(function(activity)
		return activity.value ~= "all"
	end, transformed_activities)
	if #activities == 0 then
		callback()
		return
	end
	local progress = notify.progress(string.format("Downloading 0/%d activities…", #activities))
	local completed, failed = 0, 0
	for index, activity in ipairs(activities) do
		download_activity(activity, series_padding or 0, #tostring(#activities), index - 1, function(err)
			completed = completed + 1
			failed = failed + (err and 1 or 0)
			progress:update(string.format("Downloading %d/%d activities…", completed, #activities))
			if completed == #activities then
				file_ops.process_file_queue()
				progress:finish(string.format("Downloaded %d activities%s", completed, failed > 0 and ("; " .. failed .. " without media") or ""), failed > 0 and "warn" or "info")
				callback()
			end
		end)
		end
end

function M.activitySelector(course, serie)
	local progress = notify.progress("Fetching activities for " .. serie.name .. "…")
	return manager.getActivitiesAsync(serie.id, function(err, activities)
		if err then
			progress:finish(err.message, "error")
			return
		end
		progress:finish("Activities loaded")
		local transformed_activities = M.transform_activities(course, serie, activities)

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
				else
					M.download_all_activities({ selection })
				end
			end)

			return true
		end
		)
	end)
end

return M
