local api = require("dodona.api")
local previewers = require("telescope.previewers")
local file_ops = require("dodona.utils.file_operations")

local M = {}

M.file_previewer = previewers.new_buffer_previewer({
	preview_title = "Latest submission",
	define_preview = function(self, entry)
		self.state.dodona_generation = (self.state.dodona_generation or 0) + 1
		local generation = self.state.dodona_generation
		if self.state.dodona_task then
			self.state.dodona_task:cancel()
			self.state.dodona_task = nil
		end

		local function current()
			return generation == self.state.dodona_generation and vim.api.nvim_buf_is_valid(self.state.bufnr)
		end
		local function render(content)
			if current() then
				file_ops.set_buffer_content(self.state.bufnr, content or "", entry.extension)
			end
		end

		if not entry.has_solution or entry.preview_content ~= entry.boilerplate then
			render(entry.preview_content)
			return
		end

		render("Loading latest submission…")
		local path = string.format(
			"/courses/%s/series/%s/activities/%s/submissions",
			entry.course.id,
			entry.serie.id,
			entry.value
		)
		self.state.dodona_task = api.get_async(path, {}, function(err, submissions)
			if not current() then
				return
			end
			if err then
				render("Could not load submission: " .. err.message)
				return
			end
			local latest = submissions.body and submissions.body[1]
			if not latest or not latest.url then
				render(entry.preview_content)
				return
			end
			self.state.dodona_task = api.get_async(latest.url, { full_url = true }, function(latest_err, response)
				if not current() then
					return
				end
				if latest_err then
					render("Could not load submission: " .. latest_err.message)
					return
				end
				entry.preview_content = response.body.code or entry.preview_content
				render(entry.preview_content)
			end)
		end)
	end,
})

return M
