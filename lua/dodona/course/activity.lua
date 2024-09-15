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

return M
