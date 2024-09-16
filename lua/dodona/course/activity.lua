local api = require("dodona.api")

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
	local url = "/exercises/?filter=" .. filter .. "&tab=all&page=" .. page
	local response = api.get(url, false, {})
	if response and response.body then
		return response.body.exercises, response.body.page
	end
	return {}, nil
end

-- Get the initial set of activities for the search picker
function M.getActivitiesFinder()
	local initial_page = 1
	local activities = {}
	local next_page = initial_page

	return function(prompt)
		if next_page then
			-- Fetch activities for the current search prompt
			local new_activities, next = fetchActivities(next_page, prompt)
			for _, activity in ipairs(new_activities) do
				table.insert(activities, activity)
			end
			next_page = next
		end

		-- Filter activities based on the search prompt
		local filtered_activities = {}
		for _, activity in ipairs(activities) do
			if activity.name:find(prompt) then
				table.insert(filtered_activities, {
					value = activity.id,
					display = activity.name,
					ordinal = activity.name,
				})
			end
		end
		return filtered_activities
	end
end

-- Inspect activity: Open its details (optional previewer, or other logic)
function M.inspectActivity(entry)
	-- You can open a detailed view of the activity here
	vim.notify("Inspecting activity: " .. entry.display, "info")
	-- For now, just a notification. You can extend this as needed.
end

return M
