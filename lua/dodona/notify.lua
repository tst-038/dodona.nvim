local config = require("dodona.config")

local M = {}

local levels = {
	trace = vim.log.levels.TRACE,
	debug = vim.log.levels.DEBUG,
	info = vim.log.levels.INFO,
	warn = vim.log.levels.WARN,
	error = vim.log.levels.ERROR,
}

function M.notify(message, level, opts)
	if not config.get().notify then
		return
	end
	level = level or "info"
	opts = vim.tbl_extend("force", { title = "Dodona" }, opts or {})
	local ok, notifier = pcall(require, "notify")
	if ok then
		return notifier(message, level, opts)
	end
	vim.schedule(function()
		vim.notify(message, levels[level] or vim.log.levels.INFO, opts)
	end)
end

function M.progress(message)
	local handle
	if config.get().progress then
		handle = M.notify(message, "info", { timeout = false })
	end
	local finished = false
	return {
		update = function(_, text)
			if finished or not config.get().progress then
				return
			end
			handle = M.notify(text, "info", { replace = handle, timeout = false })
		end,
		finish = function(_, text, level)
			if finished then
				return
			end
			finished = true
			M.notify(text, level or "info", { replace = handle, timeout = 3000 })
		end,
	}
end

return setmetatable(M, {
	__call = function(_, ...)
		return M.notify(...)
	end,
})
