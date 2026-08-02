local manager = require("dodona.manager")
local previewers = require("telescope.previewers")
local file_ops = require("dodona.utils.file_operations")

local M = {}

M.media_previewer = previewers.new_buffer_previewer({
	define_preview = function(self, entry)
		self.state.dodona_generation = (self.state.dodona_generation or 0) + 1
		local generation = self.state.dodona_generation
		if self.state.dodona_job then
			self.state.dodona_job:cancel()
		end
		if entry.value == "all" then
			return
		end
		file_ops.set_buffer_content(self.state.bufnr, "Loading preview…")
		self.state.dodona_job = manager.downloadToBuffer(entry.base_url, entry.url, function(buf, temp_file)
			if not buf then
				return
			end
			local current = generation == self.state.dodona_generation and vim.api.nvim_buf_is_valid(self.state.bufnr)
			if current and vim.api.nvim_buf_is_valid(buf) then
				entry.preview_content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
				file_ops.set_buffer_content(self.state.bufnr, entry.preview_content, entry.extension)
			end
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
			local uv = vim.uv or vim.loop
			uv.fs_unlink(temp_file)
		end)
	end,
})

return M
