local M = {}

local defaults = {
	base_url = "https://dodona.be",
	go_cmd = vim.fn.has("mac") == 1 and "open" or "xdg-open",
	download_on_init = false,
	request_timeout = 10000,
	poll_interval = 2000,
	poll_timeout = 60000,
	download_concurrency = 4,
	cache_ttl = 30000,
	notify = true,
	progress = true,
	debug = false,
	hooks = {
		on_error = nil,
		on_request = nil,
		on_response = nil,
	},
}

local values = vim.deepcopy(defaults)

local function validate(opts)
	vim.validate({
		base_url = { opts.base_url, "string" },
		request_timeout = { opts.request_timeout, "number" },
		poll_interval = { opts.poll_interval, "number" },
		poll_timeout = { opts.poll_timeout, "number" },
		download_concurrency = { opts.download_concurrency, "number" },
		cache_ttl = { opts.cache_ttl, "number" },
		notify = { opts.notify, "boolean" },
		progress = { opts.progress, "boolean" },
	})
	if opts.base_url == "" then
		error("dodona.nvim: base_url cannot be empty")
	end
	if opts.download_concurrency < 1 then
		error("dodona.nvim: download_concurrency must be at least 1")
	end
	opts.base_url = opts.base_url:gsub("/+$", "")
	return opts
end

function M.setup(opts)
	values = validate(vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {}))
	return values
end

function M.get()
	return values
end

return M
