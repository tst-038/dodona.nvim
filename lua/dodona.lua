local api = require("dodona.api")
local telescope = require("dodona.telescope")
local manager = require("dodona.manager")

local fn = vim.fn

local M = {}

function M.test()
	telescope.telescope()
end

function M.submit()
	local file = fn.expand("%")
	manager.evalSubmission(file)
end

function M.initActivities()
	telescope.initActivities()
end

function M.setup(vars)
	api.setup(vars)
end

return M
