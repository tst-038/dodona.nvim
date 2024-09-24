local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local notify = require("notify")

local M = {}

-- Queue to hold file entries
M.file_queue = {}

function M.sanitize_filename(filename)
	local sanitized = filename:gsub('[\\/:%*%?"<>|]', "_")
	sanitized = sanitized:gsub("^%s*(.-)%s*$", "%1")
	return sanitized
end

function M.write_to_file(entry, file_path)
	local file
	if type(entry.preview_content) == "string" then
		file = io.open(file_path, "w")
	else
		file = io.open(file_path, "wb")
	end

	if file then
		if entry.comment ~= "" and entry.comment ~= vim.NIL and entry.comment ~= nil then
			file:write(entry.comment .. " " .. entry.url .. "\n")
			if entry.has_solution and not entry.last_solution_is_best then
				file:write(entry.comment .. " WARN: This is not your best solution\n")
			end
		end

		if entry.preview_content and entry.preview_content ~= "" and entry.preview_content ~= vim.NIL then
			if type(entry.preview_content) == "string" then
				file:write(entry.preview_content)
			else
				for _, byte in ipairs(entry.preview_content) do
					file:write(byte)
				end
			end
		end

		file:close()
	else
		notify("Error writing to file: " .. file_path, "error")
	end
end

-- Function to check if a file exists and queue for writing
function M.check_and_queue_file(entry, file_path)
	local dir = vim.fn.fnamemodify(file_path, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end

	if vim.fn.filereadable(file_path) == 1 then
		M.queue_file(entry, file_path)
	else
		M.write_to_file(entry, file_path)
	end
end

-- Function to process queued files one by one, handling conflicts via picker
function M.process_file_queue()
	if #M.file_queue == 0 then
		return
	end

	local item = table.remove(M.file_queue, 1)
	local entry = item.entry
	local file_path = item.path

	local existing_file_content = table.concat(vim.fn.readfile(file_path), "\n")
	local new_file_content = entry.preview_content or ""

	pickers
			.new({}, {
				prompt_title = entry.ordinal .. "." .. entry.extension .. " already exists! What would you like to do?",
				finder = finders.new_table({
					results = { "Keep Existing", "Keep New", "Combine" },
				}),
				sorter = conf.generic_sorter({}),
				previewer = previewers.new_buffer_previewer({
					define_preview = function(self, entry_selected, status)
						local bufnr = self.state.bufnr
						if entry_selected.value == "Keep Existing" then
							M.set_buffer_content(bufnr, existing_file_content, entry.extension)
						elseif entry_selected.value == "Keep New" then
							M.set_buffer_content(bufnr, new_file_content, entry.extension)
						elseif entry_selected.value == "Combine" then
							M.set_buffer_content(
								bufnr,
								existing_file_content .. "\n\n--- NEW FILE ---\n\n" .. new_file_content,
								entry.extension
							)
						end
					end,
				}),
				attach_mappings = function(prompt_bufnr, map)
					local function on_select_action()
						local selected_action = action_state.get_selected_entry()
						if selected_action then
							actions.close(prompt_bufnr)

							if selected_action.value == "Keep Existing" then
								notify("Keeping the existing file: " .. file_path, "info")
							elseif selected_action.value == "Keep New" then
								M.write_to_file(entry, file_path)
							elseif selected_action.value == "Combine" then
								entry.preview_content = existing_file_content .. "\n\n" .. new_file_content
								M.write_to_file(entry, file_path)
							end

							M.process_file_queue()
						end
					end

					map("i", "<CR>", on_select_action)
					map("n", "<CR>", on_select_action)

					return true
				end,
			})
			:find()
end

-- Add entries to the queue
function M.queue_file(entry, file_path)
	table.insert(M.file_queue, { entry = entry, path = file_path })
end

-- Helper function to set buffer content
function M.set_buffer_content(bufnr, content, filetype)
	if content ~= vim.NIL then
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))
	end
	if filetype then
		vim.api.nvim_buf_call(bufnr, function()
			vim.cmd("setfiletype " .. filetype)
		end)
	end
end

return M
