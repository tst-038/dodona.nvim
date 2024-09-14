local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")

local M = {}

-- Helper function to create a picker
function M.create_picker(opts, results, entry_maker, prompt_title, mappings)
	pickers
		.new(opts, {
			prompt_title = prompt_title,
			finder = finders.new_table({
				results = results,
				entry_maker = entry_maker,
			}),
			sorter = sorters.get_generic_fuzzy_sorter(),
			attach_mappings = mappings,
		})
		:find()
end

return M
