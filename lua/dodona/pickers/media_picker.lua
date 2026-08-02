local manager = require("dodona.manager")
local picker_helper = require("dodona.utils.picker_helper")
local media_previewer = require("dodona.previewers.media_previewer")
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local notify = require("dodona.notify")
local file_operations = require("dodona.utils.file_operations")

local M = {}

-- Function to handle media selection and writing to file
local function handle_media_selection(entry, directory, callback)
	callback = callback or function() end
	if directory == nil then
		directory = vim.fn.expand("%:p:h")
	end
	local filepath = directory .. "/" .. entry.ordinal .. "." .. entry.extension

	if not entry.preview_content or entry.preview_content == "" or entry.preview_content:find("Binary preview", 1, true) then
		manager.downloadToBuffer(entry.base_url, entry.url, function(buf, temp_file, err)
			if err then
				callback(err)
				return
			end
			if vim.fn.filereadable(temp_file) == 1 then
				if require("dodona.file.media").isTextFile(temp_file) then
					entry.preview_content = table.concat(vim.fn.readfile(temp_file), "\n")
				else
					local file = io.open(temp_file, "rb")
					if file then
						entry.preview_content = file:read("*a")
						entry.preview_binary = true
						file:close()
					end
				end
			end

			file_operations.check_and_queue_file(entry, filepath)
			file_operations.process_file_queue()
			local uv = vim.uv or vim.loop
			uv.fs_unlink(temp_file)
			callback()
		end)
	else
		file_operations.check_and_queue_file(entry, filepath)
		callback()
	end
end

local function transform_media(file)
	return {
		url = file.url,
		display = require("dodona.utils.icon").get_icon(string.match(file.name, "%.(%w+)$")) .. file.name,
		ordinal = string.match(file.name, "(.*)%.%w+$"),
		extension = string.match(file.name, "%.(%w+)$"),
		base_url = file.base_url,
		comment = vim.NIL,
		preview_content = "",
		preview_binary = false,
	}
end

local function prepare_media(media_files)
	local media = {}
	table.insert(media, {
		display = require("dodona.utils.icon").get_download_all_media_icon() .. "All Media",
		ordinal = "All Media",
		value = "all",
	})

	for _, file in ipairs(media_files) do
		table.insert(media, transform_media(file))
	end

	return media
end

M.prepare_media = prepare_media

function M.download_all_media(media_files, directory, callback)
	callback = callback or function() end
	local downloads = {}
	for _, file in ipairs(media_files or {}) do
		if file.value ~= "all" then
			table.insert(downloads, file)
		end
	end
	local pending = #downloads
	if pending == 0 then
		callback()
		return
	end
	local first_error
	for _, file in ipairs(downloads) do
		handle_media_selection(file, directory, function(err)
			first_error = first_error or err
			pending = pending - 1
			if pending == 0 then
				callback(first_error)
			end
		end)
	end
end

function M.get_all_prepared_media(url)
	local media_files = manager.getMediaFiles(url)

	if #media_files == 0 then
		notify("No media files found", "warn")
		return
	end

	media_files = prepare_media(media_files)
	return media_files
end

-- Function to select media files
function M.mediaSelector()
	local bufnr = vim.api.nvim_get_current_buf()
	local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
	local url = first_line:match("(https?://[%w-_%.%?%.:/%+=&]+)") or ""
	url = url:gsub("/$", "")

	if url ~= "" then
		local progress = notify.progress("Fetching activity media…")
		return manager.getMediaFilesAsync(url, function(err, files)
			if err then
				progress:finish(err.message, "error")
				return
			end
			if #files == 0 then
				progress:finish("No media files found", "warn")
				return
			end
			progress:finish("Media loaded")
			local media_files = prepare_media(files)
			picker_helper.create_picker(
			{
				previewer = media_previewer.media_previewer,
			},
			media_files,
			function(entry)
				return entry
			end,
			"Select Media to Download",
			function(prompt_bufnr, map)
				map("i", "<CR>", function()
					local entry = action_state.get_selected_entry()

					if not entry then
						notify("No valid selection", "error")
						return
					end

					actions.close(prompt_bufnr)
					if entry.value == "all" then
						M.download_all_media(media_files)
						file_operations.process_file_queue()
						return
					end

					handle_media_selection(entry)
					file_operations.process_file_queue()
				end)
				return true
			end
			)
		end)
	else
		notify("Falling back to course selection", "info")
		require("dodona.pickers.year_picker").yearSelector()
	end
end

return M
