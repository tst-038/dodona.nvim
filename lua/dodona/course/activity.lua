local api = require("dodona.api")
local stringUtil = require("dodona.utils.string")
local icon = require("dodona.utils.icon")

local M = {}

-- Get the activities in a series
function M.getActivities(serie_id)
	local result = api.get("/series/" .. serie_id .. "/activities")

	if not result or result.status ~= 200 then
		vim.notify("Failed to fetch activities for series ID: " .. serie_id, "error")
		return {}
	end

	return result.body or {}
end

local function check_evaluated(url)
	local timer = vim.loop.new_timer()
	local i = 0
	-- Waits 2000ms, then repeats every 1000ms until timer:close().
	timer:start(
		2000,
		2000,
		vim.schedule_wrap(function()
			local response = api.get(url, true)

			if i > 10 or response.status ~= 200 then
				timer:close() -- Always close handles to avoid leaks.
			end

			if response.body.status ~= "running" and response.body.status ~= "queued" then
				local color
				if response.body.accepted then
					color = "info"
				else
					color = "error"
				end
				timer:close()
				vim.notify(
					response.body.status
						.. ": "
						.. tostring(response.body.summary)
						.. "\n"
						.. string.sub(response.body.url, 1, -6),
					color
				)
			end

			i = i + 1
		end)
	)
end

-- Evaluate submission for an activity
function M.evalSubmission(filename, ext)
	local file = io.open(filename, "r")

	if file == nil then
		return
	end

	local url = require("dodona.utils").split(file:read():reverse(), "/")
	local filtered = require("dodona.filter").filter(ext, file:read("*a"))
	local body = {
		submission = {
			code = filtered,
			course_id = tonumber(url[6]:reverse()),
			series_id = tonumber(url[4]:reverse()),
			exercise_id = tonumber(url[2]:reverse()),
		},
	}
	file:close()

	local response = api.post("/submissions.json", body)
	if response.body.status == "ok" and response.status == 200 then
		vim.notify("Solution has been submitted \nEvaluating...", "warn")
		check_evaluated(response.body.url)
	else
		vim.notify("Submit failed!!!", "error")
	end
end

-- Helper function to fetch activities based on page number and filter
local function fetchActivities(page, filter)
	local params = {
		filter = filter,
		tab = "all",
		page = page,
	}
	local response = api.get("/exercises/", false, params)
	if response and response.body then
		return response.body
	end
	return {}
end

-- Get the initial set of activities for the search picker
function M.getActivitiesFinder()
	return function(prompt)
		local activities = fetchActivities(1, prompt)
		local filtered_activities = {}
		for _, activity in ipairs(activities) do
			if activity.name:find(prompt) then
				table.insert(filtered_activities, {
					value = activity.id,
					display = icon.get_icon(activity.programming_language.name)
						.. stringUtil.pad_string(icon.get_status_icon(activity), icon.STATUS_PADDING_LENGTH)
						.. activity.name,
					ordinal = activity.name,
					has_correct_solution = activity.has_correct_solution,
					has_solution = activity.has_solution,
				})
			end
		end
		return filtered_activities
	end
end

-- Inspect activity: Open its details (optional previewer, or other logic)
function M.inspectActivity(entry)
	vim.notify("Inspecting activity: " .. entry.display, "info")
end

return M
