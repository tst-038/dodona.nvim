local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local courses = require("dodona.course.course")
local activities = require("dodona.course.activity")
local notify = require("dodona.notify")
local picker_helper = require("dodona.utils.picker_helper")

local M = {}

local function select_mapping(handler)
	return function(prompt_bufnr, map)
		local function select()
			local entry = action_state.get_selected_entry()
			actions.close(prompt_bufnr)
			if entry then
				handler(entry)
			end
		end
		map("i", "<CR>", select)
		map("n", "<CR>", select)
		return true
	end
end

local function ask_and_search(title, fetch, inspect)
	vim.ui.input({ prompt = title .. ": " }, function(query)
		if not query or query:match("^%s*$") then
			return
		end
		local progress = notify.progress("Searching Dodona…")
		fetch(query, function(err, results)
			if err then
				progress:finish(err.message, "error")
				return
			end
			if #results == 0 then
				progress:finish("No results found", "warn")
				return
			end
			progress:finish(string.format("Found %d result%s", #results, #results == 1 and "" or "s"))
			picker_helper.create_picker({}, results, function(entry)
				return entry
			end, title, select_mapping(inspect))
		end)
	end)
end

function M.searchCourses()
	ask_and_search("Search courses", courses.searchCoursesAsync, function(entry)
		courses.inspectCourse(entry.course)
	end)
end

function M.searchActivities()
	ask_and_search("Search activities", activities.searchActivitiesAsync, activities.inspectActivity)
end

function M.search()
	picker_helper.create_picker({
		prompt_title = "Search Dodona",
		finder = finders.new_table({
			results = {
				{ display = "Search Courses", ordinal = "courses", action = M.searchCourses },
				{ display = "Search Activities", ordinal = "activities", action = M.searchActivities },
			},
		}),
		attach_mappings = select_mapping(function(entry)
			entry.action()
		end),
	})
end

return M
