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

-- Evaluate submission for an activity
function M.evalSubmission(submission_id)
	local result = api.post("/submissions/" .. submission_id .. "/evaluate", {})

	if not result or result.status ~= 200 then
		vim.notify("Failed to evaluate submission ID: " .. submission_id, "error")
		return {}
	end

	return result.body or {}
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
