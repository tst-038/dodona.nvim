local manager = require("dodona.manager")
local previewers = require("telescope.previewers")
local file_ops = require("dodona.utils.file_operations")

local M = {}

M.media_previewer = previewers.new_buffer_previewer({
	define_preview = function(self, entry)
		if entry.value == "all" then
			return
		end
		manager.downloadToBuffer(entry.base_url, entry.url, function(buf)
			entry.preview_content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
			file_ops.set_buffer_content(self.state.bufnr, entry.preview_content, entry.display:match("^.+%.([^%.]+)$"))
		end)
	end,
})

return M
