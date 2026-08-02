local Task = require("dodona.task")

local M = {}
local config = {}

local function curl()
	local ok, module = pcall(require, "plenary.curl")
	if not ok then
		error("dodona.nvim requires nvim-lua/plenary.nvim for API requests", 3)
	end
	return module
end

local function call_hook(name, ...)
	local hook = config.hooks and config.hooks[name]
	if type(hook) == "function" then
		pcall(hook, ...)
	end
end

local function api_error(message, response)
	local err = {
		message = message,
		status = response and response.status or 0,
		response = response,
	}
	call_hook("on_error", err)
	return err
end

local function headers(has_body)
	if type(config.token) ~= "string" or config.token == "" then
		error("No Dodona API token configured. Run :DodonaSetToken first.", 3)
	end
	local result = {
		Authorization = config.token,
		Accept = "application/json",
	}
	if has_body then
		result["Content-Type"] = "application/json"
	end
	return result
end

local function encode(value)
	return vim.uri_encode(tostring(value))
end

function M.build_url(url, params)
	if not params or vim.tbl_isempty(params) then
		return url
	end
	local keys = vim.tbl_keys(params)
	table.sort(keys)
	local query = {}
	for _, key in ipairs(keys) do
		table.insert(query, encode(key) .. "=" .. encode(params[key]))
	end
	return url .. (url:find("?", 1, true) and "&" or "?") .. table.concat(query, "&")
end

local function resolve_url(path, full_url, params)
	local url = full_url and path or config.base_url .. path
	return M.build_url(url, params)
end

local function decode(response, expect_json)
	if not response or response.exit and response.exit ~= 0 then
		return nil, api_error("Network request failed", response)
	end
	if not response.status or response.status < 200 or response.status >= 300 then
		local message = response.status == 401 and "Unauthorized: run :DodonaSetToken with a valid token"
			or ("Dodona returned HTTP " .. tostring(response.status or 0))
		return nil, api_error(message, response)
	end

	local body = response.body
	if expect_json and body and body ~= "" then
		local ok, decoded = pcall(vim.json.decode, body)
		if not ok then
			return nil, api_error("Dodona returned invalid JSON", response)
		end
		body = decoded
	end
	local result = { status = response.status, body = body, headers = response.headers }
	call_hook("on_response", result)
	return result
end

local function spec(method, path, opts)
	opts = opts or {}
	local request = {
		method = method,
		url = resolve_url(path, opts.full_url, opts.params),
		headers = headers(opts.body ~= nil),
		timeout = opts.timeout or config.request_timeout or 10000,
	}
	request.raw = { "--max-time", tostring(math.max(1, math.ceil(request.timeout / 1000))) }
	if opts.body ~= nil then
		request.body = vim.json.encode(opts.body)
	end
	call_hook("on_request", { method = method, url = request.url })
	return request
end

function M.request(method, path, opts)
	local request = spec(method, path, opts)
	local response = curl().request(request)
	local result, err = decode(response, not opts or opts.json ~= false)
	if err then
		return { status = err.status, body = {}, error = err }
	end
	return result
end

function M.request_async(method, path, opts, callback)
	callback = callback or function() end
	local task = Task.new()
	local spec_ok, request = pcall(spec, method, path, opts)
	if not spec_ok then
		task:finish()
		vim.schedule(function()
			callback(api_error((tostring(request):gsub("^.-:%d+: ", ""))), nil)
		end)
		return task
	end
	request.callback = function(response)
		vim.schedule(function()
			if task.cancelled then
				return
			end
			task:finish()
			local result, err = decode(response, not opts or opts.json ~= false)
			callback(err, result)
		end)
	end
	request.on_error = function(err)
		vim.schedule(function()
			if task.cancelled then
				return
			end
			task:finish()
			callback(api_error(err.message or "Network request failed"), nil)
		end)
	end
	local curl_ok, client = pcall(curl)
	if not curl_ok then
		task:finish()
		vim.schedule(function()
			callback(api_error((tostring(client):gsub("^.-:%d+: ", ""))), nil)
		end)
		return task
	end
	local job_ok, job = pcall(client.request, request)
	if not job_ok then
		task:finish()
		vim.schedule(function()
			callback(api_error((tostring(job):gsub("^.-:%d+: ", ""))), nil)
		end)
		return task
	end
	task._cancel = function()
		if job and job.shutdown then
			job:shutdown()
		end
	end
	return task
end

function M.setup(opts)
	config = opts or {}
end

function M.get(path, full_url, params)
	return M.request("get", path, { full_url = full_url, params = params })
end

function M.get_async(path, opts, callback)
	return M.request_async("get", path, opts or {}, callback)
end


function M.gethtml(path)
	return M.request("get", path, { full_url = true, json = false })
end

function M.gethtml_async(path, callback)
	return M.request_async("get", path, { full_url = true, json = false }, callback)
end

function M.post(path, body)
	return M.request("post", path, { body = body })
end

function M.post_async(path, body, callback)
	return M.request_async("post", path, { body = body }, callback)
end

function M.put(path, body)
	return M.request("put", path, { body = body })
end

function M.put_async(path, body, callback)
	return M.request_async("put", path, { body = body }, callback)
end

return M
