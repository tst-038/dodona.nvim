local api = require("dodona.api")
local config = require("dodona.config")
local icon = require("dodona.utils.icon")
local notify = require("dodona.notify")
local Task = require("dodona.task")
local cache = require("dodona.cache")

local M = {}

function M.getActivities(series_id)
	local key = "activities:" .. series_id
	local cached = cache.get(key)
	if cached then
		return cached
	end
	local result = api.get("/series/" .. series_id .. "/activities")
	if result.error then
		notify(result.error.message, "error")
		return {}
	end
	local activities = result.body or {}
	cache.set(key, activities)
	return activities
end

function M.getActivitiesAsync(series_id, callback)
	local key = "activities:" .. series_id
	return cache.fetch(key, function(done)
		api.get_async("/series/" .. series_id .. "/activities", {}, function(err, result)
			done(err, result and result.body or {})
		end)
	end, callback)
end

local function parse_submission(content, extension)
	local course_id, series_id, exercise_id = content:match(
		"https?://[^%s]+/courses/(%d+)/series/(%d+)/activities/(%d+)"
	)
	if not course_id then
		return nil, "No valid Dodona activity URL found in the file"
	end
	return {
		submission = {
			code = require("dodona.filter").filter(extension, content),
			course_id = tonumber(course_id),
			series_id = tonumber(series_id),
			exercise_id = tonumber(exercise_id),
		},
	}
end

local function poll_submission(url, task, progress)
	local started = (vim.uv or vim.loop).now()
	local timer = (vim.uv or vim.loop).new_timer()
	local request

	local function stop()
		if timer and not timer:is_closing() then
			timer:stop()
			timer:close()
		end
	end

	task._cancel = function()
		stop()
		if request then
			request:cancel()
		end
		progress:finish("Evaluation cancelled", "warn")
	end

	local function poll()
		if task.cancelled then
			return stop()
		end
		if (vim.uv or vim.loop).now() - started >= config.get().poll_timeout then
			stop()
			task:finish()
			progress:finish("Evaluation timed out", "warn")
			return
		end
		request = api.get_async(url, { full_url = true }, function(err, response)
			if err then
				stop()
				task:finish()
				progress:finish(err.message, "error")
				return
			end
			local body = response.body or {}
			if body.status == "queued" or body.status == "running" then
				progress:update("Evaluating submission… " .. body.status)
				return
			end
			stop()
			task:finish()
			local summary = body.summary and (": " .. tostring(body.summary)) or ""
			progress:finish(tostring(body.status or "Evaluation completed") .. summary, body.accepted and "info" or "error")
		end)
	end

	timer:start(0, config.get().poll_interval, vim.schedule_wrap(poll))
end

function M.evalSubmission(filename, extension)
	local file, err = io.open(filename, "r")
	if not file then
		notify("Could not read file: " .. tostring(err), "error")
		return
	end
	local content = file:read("*a")
	file:close()
	return M.evalSubmissionContent(content, extension)
end

function M.evalSubmissionContent(content, extension)
	local body, parse_error = parse_submission(content, extension)
	if not body then
		notify(parse_error, "error")
		return
	end

	local progress = notify.progress("Submitting solution…")
	local task = Task.new()
	local request = api.post_async("/submissions.json", body, function(err, response)
		if task.cancelled then
			return
		end
		if err then
			task:finish()
			progress:finish(err.message, "error")
			return
		end
		local result = response.body or {}
		if not result.url then
			task:finish()
			progress:finish("Dodona did not return an evaluation URL", "error")
			return
		end
		progress:update("Solution submitted; waiting for evaluation…")
		poll_submission(result.url, task, progress)
	end)
	task._cancel = function()
		request:cancel()
		progress:finish("Submission cancelled", "warn")
	end
	return task
end

local function fetchActivities(page, filter)
	local response = api.get("/exercises/", false, { filter = filter, tab = "all", page = page })
	return response.body or {}
end

function M.getActivitiesFinder()
	return function(prompt)
		local transformed = {}
		for _, activity in ipairs(fetchActivities(1, prompt)) do
			table.insert(transformed, {
				value = activity.id,
				display = icon.get_icon(activity.programming_language.name) .. icon.get_status_icon(activity) .. activity.name,
				ordinal = activity.name,
				url = activity.url,
				activity = activity,
			})
		end
		return transformed
	end
end

function M.searchActivitiesAsync(prompt, callback)
	return api.get_async("/exercises/", {
		params = { filter = prompt, tab = "all", page = 1 },
	}, function(err, response)
		if err then
			callback(err, {})
			return
		end
		local transformed = {}
		for _, activity in ipairs(response.body or {}) do
			table.insert(transformed, {
				value = activity.id,
				display = icon.get_icon(activity.programming_language.name) .. icon.get_status_icon(activity) .. activity.name,
				ordinal = activity.name,
				url = activity.url,
				activity = activity,
			})
		end
		callback(nil, transformed)
	end)
end

function M.inspectActivity(entry)
	local url = type(entry) == "table" and (entry.url or entry.activity and entry.activity.url) or nil
	if not url then
		notify("This activity has no URL", "warn")
		return
	end
	vim.ui.open(url:gsub("%.json$", ""))
end

return M
