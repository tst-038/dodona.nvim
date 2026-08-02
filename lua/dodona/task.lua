local M = {}
M.__index = M
local active = setmetatable({}, { __mode = "k" })

function M.new(cancel)
	local task = setmetatable({
		_cancel = cancel,
		cancelled = false,
		done = false,
	}, M)
	active[task] = true
	return task
end

function M:cancel()
	if self.done or self.cancelled then
		return
	end
	self.cancelled = true
	active[self] = nil
	if self._cancel then
		pcall(self._cancel)
	end
end

function M:finish()
	self.done = true
	active[self] = nil
end

function M.cancel_all()
	local count = 0
	for task in pairs(active) do
		task:cancel()
		count = count + 1
	end
	return count
end

return M
