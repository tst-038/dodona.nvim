local notify = require("notify")

local M = {}

-- Helper function to write content to a file
function M.write_to_file(entry, file_path)
	local file = io.open(file_path, "w")
	if file then
		file:write(entry.comment .. " " .. entry.url .. "\n")

		if entry.preview_content and entry.preview_content ~= "" then
			file:write(entry.preview_content)
		end

		file:close()
		notify("File written: " .. file_path, "info")
	else
		notify("Error writing to file: " .. file_path, "error")
	end
end

-- Function to check if a file exists and prompt the user to override it
function M.check_and_write_file(entry, file_name)
	local file_path = vim.fn.getcwd() .. "/" .. file_name

	if vim.fn.filereadable(file_path) == 1 then
		vim.ui.select({ "Yes", "No" }, {
			prompt = "File already exists! Do you want to override it?",
		}, function(choice)
			if choice == "Yes" then
				M.write_to_file(entry, file_path)
			else
				notify("File not overwritten: " .. file_name, "info")
			end
		end)
	else
		M.write_to_file(entry, file_path)
	end
end

-- Helper function to set buffer content
function M.set_buffer_content(bufnr, content, filetype)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))
	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd("setfiletype " .. filetype)
	end)
end

return M
