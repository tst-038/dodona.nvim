local curl = require("plenary.curl")
local fn = vim.fn

local M = {}

local config = {}

-- Utility function to handle API response evaluation
local function evaluate(result)
	if result.status ~= 200 then
		vim.schedule(function()
			vim.notify("Cannot execute request.")
			if result.status == 401 then
				vim.notify("Unauthorized request: make sure you have working token.")
			end
		end)
		return { status = result.status, body = {} }
	end
	return { body = fn.json_decode(result.body), status = result.status }
end

-- Function to initialize the base URL and token
function M.setup(table)
	config.token = table.token
	config.base_url = table.base_url
end

-- Utility function to build URLs with query parameters
function M.build_url(url, params)
	if params then
		local query = {}
		for k, v in pairs(params) do
			table.insert(query, k .. "=" .. v)
		end
		url = url .. "?" .. table.concat(query, "&")
	end
	return url
end

-- GET request, with optional query parameters
function M.get(url, full_url, params)
	if not full_url then
		url = M.build_url(config.base_url .. url, params)
	end

	url = url:gsub("/.json$", ".json")

	local output = curl.get({
		url = url,
		accept = "application/json",
		headers = {
			content_type = "application/json",
			Authorization = config.token,
		},
		timeout = 5000,
	})
	return evaluate(output)
end

-- GET request for HTML response
function M.gethtml(url)
	local output = curl.get({
		url = url,
		headers = {
			Authorization = config.token,
		},
		timeout = 5000,
	})
	return output
end

-- POST request
function M.post(url, body)
	local json = fn.json_encode(body)
	local output = curl.post({
		body = json,
		url = config.base_url .. url,
		headers = {
			content_type = "application/json",
			Authorization = config.token,
		},
		timeout = 5000,
	})
	return evaluate(output)
end

-- PUT request (for updating data)
function M.put(url, body)
	local json = fn.json_encode(body)
	local output = curl.put({
		body = json,
		url = config.base_url .. url,
		headers = {
			content_type = "application/json",
			Authorization = config.token,
		},
		timeout = 5000,
	})
	return evaluate(output)
end

return M
