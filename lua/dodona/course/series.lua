local api = require("dodona.api")
local notify = require("dodona.notify")
local cache = require("dodona.cache")

local M = {}

-- Get the series available in a course
function M.getSeries(course_id)
	local key = "series:" .. course_id
	local cached = cache.get(key)
	if cached then
		return cached
	end
	local result = api.get("/courses/" .. course_id .. "/series")

	if not result or result.status ~= 200 then
		notify("Failed to fetch series for course ID: " .. course_id, "error")
		return {}
	end

	local series = result.body or {}
	cache.set(key, series)
	return series
end

function M.getSeriesAsync(course_id, callback)
	local key = "series:" .. course_id
	return cache.fetch(key, function(done)
		api.get_async("/courses/" .. course_id .. "/series", {}, function(err, result)
			done(err, result and result.body or {})
		end)
	end, callback)
end

return M
