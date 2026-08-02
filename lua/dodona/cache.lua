local config = require("dodona.config")
local Task = require("dodona.task")

local M = {}
local entries = {}
local pending = {}

local function now()
	return (vim.uv or vim.loop).now()
end

function M.get(key)
	local entry = entries[key]
	if not entry then
		return nil
	end
	if entry.expires <= now() then
		entries[key] = nil
		return nil
	end
	return vim.deepcopy(entry.value)
end

function M.set(key, value, ttl)
	entries[key] = {
		value = vim.deepcopy(value),
		expires = now() + (ttl or config.get().cache_ttl),
	}
end

function M.invalidate(prefix)
	for key in pairs(entries) do
		if not prefix or key:sub(1, #prefix) == prefix then
			entries[key] = nil
		end
	end
end

function M.fetch(key, loader, callback)
	local task = Task.new()
	local cached = M.get(key)
	if cached ~= nil then
		vim.schedule(function()
			if not task.cancelled then
				task:finish()
				callback(nil, cached)
			end
		end)
		return task
	end

	pending[key] = pending[key] or {}
	table.insert(pending[key], { task = task, callback = callback })
	if #pending[key] > 1 then
		return task
	end

	loader(function(err, value)
		local listeners = pending[key] or {}
		pending[key] = nil
		if not err then
			M.set(key, value)
		end
		for _, listener in ipairs(listeners) do
			if not listener.task.cancelled then
				listener.task:finish()
				listener.callback(err, vim.deepcopy(value))
			end
		end
	end)
	return task
end

function M.clear()
	entries = {}
	pending = {}
end

return M
