local api = require("dodona.api")
local Job = require("plenary.job")
local notify = require("dodona.notify")
local download_queue = require("dodona.download_queue")

local M = {}

function M.isTextFile(path)
	local file = io.open(path, "rb")
	if not file then
		return false
	end
	local sample = file:read(4096) or ""
	file:close()
	return not sample:find("\0", 1, true)
end

local function extract_media(description, base_url)
	local handled = {}
	local media_files = {}
	for value in string.gmatch(description or "", '"media/.-"') do
		local clean_url = value:gsub('^"', ""):gsub('"$', "")
		if not handled[clean_url] then
			handled[clean_url] = true
			table.insert(media_files, {
				url = clean_url,
				name = clean_url:match("([^/]+)$"),
				base_url = base_url,
			})
		end
	end
	return media_files
end

-- Function to get media files from the API
function M.getMediaFiles(url)
	url = url:gsub("/+$", "")
	local response = api.get(url .. ".json", true)

	if response.status ~= 200 then
		notify("Failed to fetch media metadata from: " .. url, "error")
		return {}
	end

	local description = api.gethtml(response.body.description_url).body
	return extract_media(description, response.body.description_url)
end

function M.getMediaFilesAsync(url, callback)
	url = url:gsub("/+$", "")
	return api.get_async(url .. ".json", { full_url = true }, function(err, response)
		if err then
			callback(err, {})
			return
		end
		local description_url = response.body and response.body.description_url
		if not description_url then
			callback({ message = "Dodona returned no activity description" }, {})
			return
		end
		api.gethtml_async(description_url, function(html_err, html)
			if html_err then
				callback(html_err, {})
				return
			end
			callback(nil, extract_media(html.body, description_url))
		end)
	end)
end

-- Function to download a file and load it into a buffer
function M.downloadToBuffer(base_url, w, callback)
	local temp_file = vim.fn.tempname()
	local queued_task
	queued_task = download_queue.enqueue(function(done)
		local job = Job:new({
			command = "curl",
			args = { "--fail", "--location", "--silent", "--show-error", base_url .. w, "--output", temp_file },
				on_exit = function(_, return_val)
					done()
					if queued_task and queued_task.cancelled then
						local uv = vim.uv or vim.loop
						uv.fs_unlink(temp_file)
						return
					end
				if return_val == 0 then
					vim.schedule(function()
						local buf = vim.api.nvim_create_buf(false, true)

						if M.isTextFile(temp_file) then
							local content = vim.fn.readfile(temp_file)
							vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
						else
							vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Binary preview is not supported" })
						end

						if callback then
							callback(buf, temp_file)
						else
							local uv = vim.uv or vim.loop
							uv.fs_unlink(temp_file)
						end
					end)
				else
					vim.schedule(function()
						local message = "Error when downloading: " .. (w:match("([^/]+)$") or w)
						notify(message, "error")
						if callback then
							callback(nil, temp_file, message)
						end
					end)
				end
			end,
		})
		job:start()
		return job
	end, function(err)
		notify("Could not start download: " .. tostring(err), "error")
		if callback then
			callback(nil, temp_file, err)
		end
	end)
	return queued_task
end

return M
