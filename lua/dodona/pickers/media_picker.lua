local manager = require("dodona.manager")
local picker_helper = require("dodona.utils.picker_helper")
local media_previewer = require("dodona.previewers.media_previewer")
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local notify = require("notify")
local file_operations = require("dodona.utils.file_operations")

local M = {}

-- Function to handle media selection and writing to file
local function handle_media_selection(entry, directory)
	if directory == nil then
		directory = vim.fn.expand("%:p:h")
	end
	local filepath = directory .. "/" .. entry.ordinal .. "." .. entry.extension

	if entry.preview_content:match("Preview not supported for file type") ~= "" then
		manager.downloadToBuffer(entry.base_url, entry.url, function(buf, temp_file)
			if vim.fn.filereadable(temp_file) == 1 then
				local mime_type = vim.fn.system("file --mime-type -b " .. temp_file):gsub("%s+", "")

				if mime_type:find("^text/") or mime_type:find("^application/json") then
					entry.preview_content = table.concat(vim.fn.readfile(temp_file), "\n")
				else
					local binary_content = io.open(temp_file, "rb"):read("*all")
					entry.preview_content = binary_content
				end
			end

			file_operations.check_and_queue_file(entry, filepath)
		end)
	else
		file_operations.check_and_queue_file(entry, filepath)
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

function M.download_all_media(media_files, directory)
	if media_files ~= nil then
		for _, file in ipairs(media_files) do
			if file.value ~= "all" then
				handle_media_selection(file, directory)
			end
		end
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
		local media_files = M.get_all_prepared_media(url)
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
	else
		notify("Falling back to course selection", "info")
		require("dodona.pickers.year_picker").yearSelector()
	end
end

return M
