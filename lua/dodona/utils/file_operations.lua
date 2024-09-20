local notify = require("notify")

local M = {}

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
		notify("File written: " .. file_path, "info")
	else
		notify("Error writing to file: " .. file_path, "error")
	end
end

-- Function to check if a file exists and prompt the user to override it
function M.check_and_write_file(entry, file_path)
	if vim.fn.filereadable(file_path) == 1 then
		vim.ui.select({ "Yes", "No" }, {
			prompt = entry.ordinal .. "." .. entry.extension .. " already exists! Do you want to override it?",
		}, function(choice)
			if choice == "Yes" then
				M.write_to_file(entry, file_path)
			else
				notify("File not overwritten: " .. file_path, "info")
			end
		end)
	else
		M.write_to_file(entry, file_path)
	end
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
