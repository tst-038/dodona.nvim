local api = require("dodona.api")
local utils = require("dodona.utils")
local Job = require("plenary.job")
local notify = require("notify")

local M = {}

-- Function to get media files from the API
function M.getMediaFiles(url)
	local response = api.get(url .. ".json", true)

	if response.status ~= 200 then
		notify("Failed to fetch media metadata from: " .. url, "error")
		return {}
	end

	local description = api.gethtml(response.body.description_url).body
	local handled = {}
	local media_files = {}

	for w in string.gmatch(description, '"media/.-"') do
		local clean_url = w:gsub('^"', ""):gsub('"$', "")
		if
				not utils.has_value(handled, clean_url)
				and not clean_url:find(".png")
				and not clean_url:find(".jpg")
				and not clean_url:find(".zip")
		then
			table.insert(media_files, {
				url = clean_url,
				name = string.sub(clean_url, clean_url:find("/[^/]*$") + 1),
				base_url = response.body.description_url,
			})
			table.insert(handled, clean_url)
		end
	end

	return media_files
end

-- Function to download a file and load it into a buffer
function M.downloadToBuffer(base_url, w, callback)
	local temp_file = vim.fn.tempname()
	Job:new({
		command = "wget",
		args = { base_url .. w, "-O", temp_file },
		on_exit = function(_, return_val)
			if return_val == 0 then
				vim.schedule(function()
					local mime_type = vim.fn.system("file --mime-type -b " .. temp_file):gsub("%s+", "")

					local buf = vim.api.nvim_create_buf(false, true)

					if mime_type:find("^text/") or mime_type:find("^application/json") then
						local content = vim.fn.readfile(temp_file)
						vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
					else
						vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
							"Preview not supported for file type: " .. mime_type,
						})
					end

					if callback then
						callback(buf)
					end
				end)
			else
				vim.schedule(function()
					notify("Error when downloading: " .. string.sub(w, w:find("/[^/]*$") + 1, -1), "error")
				end)
			end
		end,
	}):start()
end

return M
