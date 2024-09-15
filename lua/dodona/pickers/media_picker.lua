local manager = require("dodona.manager")
local picker_helper = require("dodona.utils.picker_helper")
local media_previewer = require("dodona.previewers.media_previewer")
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local utils = require("dodona.utils")
local file_operations = require("dodona.utils.file_operations")

local M = {}

-- Function to handle media selection and writing to file
local function handle_media_selection(prompt_bufnr, entry)
	local content_to_write = entry.preview_content or ""
	local filepath = vim.fn.getcwd() .. "/" .. entry.display

	if vim.fn.filereadable(filepath) == 1 then
		vim.ui.select({ "Yes", "No" }, {
			prompt = "File already exists! Do you want to override it?",
		}, function(choice)
			if choice == "Yes" then
				file_operations.write_to_file(filepath, content_to_write)
			else
				vim.notify("File not overwritten: " .. filepath, "info")
			end
		end)
	else
		file_operations.write_to_file(filepath, content_to_write)
	end

	actions.close(prompt_bufnr)
end

-- Function to select media files
function M.mediaSelector()
	local bufnr = vim.api.nvim_get_current_buf()
	local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
	local url = first_line:match("(https?://[%w-_%.%?%.:/%+=&]+)") or ""
	url = url:gsub("/$", "")

	if url ~= "" then
		local media_files = manager.getMediaFiles(url)

		if #media_files == 0 then
			vim.notify("No media files found", "warn")
			return
		end

		picker_helper.create_picker(
			{
				previewer = media_previewer.media_previewer,
			},
			media_files,
			function(file)
				return {
					value = file.url,
					display = file.name,
					ordinal = file.name,
					base_url = file.base_url,
					preview_content = "",
				}
			end,
			"Select Media to Download",
			function(prompt_bufnr, map)
				map("i", "<CR>", function()
					local entry = action_state.get_selected_entry()

					if not entry then
						vim.notify("No valid selection", "error")
						return
					end

					handle_media_selection(prompt_bufnr, entry)
				end)
				return true
			end
		)
	else
		vim.notify("Falling back to course selection", "info")
		require("dodona.pickers.year_picker").yearSelector()
	end
end

return M
