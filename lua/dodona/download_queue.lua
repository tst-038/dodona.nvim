local config = require("dodona.config")
local Task = require("dodona.task")

local M = {}
local waiting = {}
local running = 0

local function pump()
	while running < config.get().download_concurrency and #waiting > 0 do
		local item = table.remove(waiting, 1)
		if not item.task.cancelled then
			running = running + 1
			item.running = true
			local completed = false
			local function done()
				if completed then
					return
				end
				completed = true
				running = math.max(0, running - 1)
				item.task:finish()
				vim.schedule(pump)
			end
			local ok, handle = pcall(item.start, done)
			item.handle = handle
			if not ok then
				done()
				vim.schedule(function()
					item.on_error(handle)
				end)
			end
		end
	end
end

function M.enqueue(start, on_error)
	local item = {
		start = start,
		on_error = on_error or function() end,
		running = false,
	}
	item.task = Task.new(function()
		if item.running and item.handle then
			if item.handle.cancel then
				pcall(item.handle.cancel, item.handle)
			elseif item.handle.shutdown then
				pcall(item.handle.shutdown, item.handle)
			end
		else
			for index, queued in ipairs(waiting) do
				if queued == item then
					table.remove(waiting, index)
					break
				end
			end
		end
	end)
	table.insert(waiting, item)
	pump()
	return item.task
end

function M.stats()
	return { running = running, waiting = #waiting }
end

return M
