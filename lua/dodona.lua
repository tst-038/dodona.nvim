local fn = vim.fn
local config = require("dodona.config")
local notify = require("dodona.notify")

local M = {}

local function token_path()
	return vim.fn.stdpath("data") .. "/dodona/token"
end

local function trim(value)
	return value and value:match("^%s*(.-)%s*$") or nil
end

local function normalize_token(value)
	local token = trim(value)
	return token ~= "" and token or nil
end

local function read_token()
	local file = io.open(token_path(), "r")
	if not file then
		return nil
	end

	local token = normalize_token(file:read("*a"))
	file:close()
	return token
end

local function write_token(token)
	local path = token_path()
	local directory = vim.fn.fnamemodify(path, ":h")
	if vim.fn.mkdir(directory, "p", 448) == 0 and vim.fn.isdirectory(directory) == 0 then
		return nil, "Could not create token directory: " .. directory
	end

	local uv = vim.uv or vim.loop
	local directory_secured, directory_error = uv.fs_chmod(directory, 448) -- 0700
	if not directory_secured then
		return nil, directory_error
	end
	if uv.fs_stat(path) then
		local file_secured, chmod_error = uv.fs_chmod(path, 384) -- 0600
		if not file_secured then
			return nil, chmod_error
		end
	end
	local fd, open_error = uv.fs_open(path, "w", 384) -- 0600
	if not fd then
		return nil, open_error
	end

	local written, write_error = uv.fs_write(fd, token, 0)
	uv.fs_close(fd)
	if not written or written ~= #token then
		return nil, write_error or "Incomplete token write"
	end
	return true
end

function M.submit()
	local extension = fn.expand("%:e")
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local content = table.concat(lines, "\n")
	return require("dodona.manager").evalSubmissionContent(content, extension)
end

function M.initActivities()
	require("dodona.pickers.year_picker").yearSelector()
end

function M.download()
	require("dodona.pickers.media_picker").mediaSelector()
end

function M.search()
	require("dodona.pickers.search_picker").search()
end

function M.cancel()
	local count = require("dodona.task").cancel_all()
	notify(count > 0 and ("Cancelled " .. count .. " active operation(s)") or "No active Dodona operations", count > 0 and "info" or "warn")
end

function M.clearCache()
	require("dodona.cache").clear()
	notify("Course, series, and activity cache cleared", "info")
end

function M.go()
	local first_line = require("dodona.utils").readbuffer(0, 1)[1] or ""
	local url = first_line:match("(https?://%S+)")
	if not url then
		notify("No Dodona URL found on the first line", "warn")
		return
	end
	url = url:gsub("[%)%]%},;]+$", "")
	local command = config.get().go_cmd
	if command and command ~= "" then
		local args = vim.fn.shellsplit(command)
		table.insert(args, url)
		vim.system(args, { detach = true }, function(result)
			if result.code ~= 0 then
				vim.schedule(function()
					notify("Could not open Dodona URL", "error")
				end)
			end
		end)
	else
		vim.ui.open(url)
	end
end

function M.token()
	return read_token()
end

function M.setup(vars)
	vars = vars or {}
	vars.token = normalize_token(vars.token) or read_token()
	local previous = config.get()
	local identity_changed = previous.token ~= vars.token or (vars.base_url and previous.base_url ~= vars.base_url:gsub("/+$", ""))
	local values = config.setup(vars)
	if identity_changed then
		require("dodona.cache").clear()
	end
	require("dodona.api").setup(values)
	return values
end

function M.setToken()
	local token = normalize_token(vim.fn.inputsecret("Dodona API token: "))
	if not token then
		notify("Token was not changed: no token entered", "warn")
		return
	end

	local ok, err = write_token(token)
	if not ok then
		notify("Could not save token: " .. tostring(err), "error")
		return
	end

	local values = config.get()
	values.token = token
	require("dodona.cache").clear()
	require("dodona.api").setup(values)
	notify("Token saved securely", "info")
end

function M.get_download_on_init_config_field()
	return config.get().download_on_init
end

return M
