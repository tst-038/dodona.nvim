local api = require("dodona.api")
local previewers = require("telescope.previewers")
local file_ops = require("dodona.utils.file_operations")

local M = {}

M.file_previewer = previewers.new_buffer_previewer({
	preview_title = "Latest submission",
	define_preview = function(self, entry)
		if entry.has_solution and entry.preview_content == entry.boilerplate then
			local submissions = api.get(
				"/courses/"
					.. entry.course
					.. "/series/"
					.. entry.serie
					.. "/activities/"
					.. entry.value
					.. "/submissions",
				false
			)

			if submissions and #submissions.body > 0 then
				local latest_submission_url = submissions.body[1].url
				local latest_submission = api.get(latest_submission_url, true)

				if latest_submission and latest_submission.body.code and latest_submission.body.code ~= "" then
					entry.preview_content = latest_submission.body.code
				end
			end
		end
		file_ops.set_buffer_content(self.state.bufnr, entry.preview_content, entry.extension)
	end,
})

return M
