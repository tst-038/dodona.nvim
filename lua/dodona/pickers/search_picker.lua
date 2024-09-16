local picker_helper = require("dodona.utils.picker_helper")
local courses = require("dodona.course.course")
local activities = require("dodona.course.activity")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local action_state = require("telescope.actions.state")

local M = {}

-- Key bindings for activity search picker
local function attach_activity_mappings(prompt_bufnr, map)
	map("i", "<CR>", function()
		local entry = action_state.get_selected_entry()
		actions.close(prompt_bufnr)
		-- Action for inspecting an activity
		activities.inspectActivity(entry.course_id)
	end)
	return true
end

-- Key bindings for course search picker (as previously defined)
local function attach_course_mappings(prompt_bufnr, map)
	map("i", "<CR>", function()
		local entry = action_state.get_selected_entry()
		actions.close(prompt_bufnr)
		-- Action for inspecting a course (open series view)
		courses.inspectCourse(entry)
	end)

	map("i", "<Tab>", function()
		local entry = action_state.get_selected_entry()
		actions.close(prompt_bufnr)
		-- Toggle subscribe/unsubscribe for the course
		courses.toggleSubscription(entry)
	end)

	return true
end

-- Open search picker for courses
function M.searchCourses()
	local opts = {
		prompt_title = "Search Courses",
		finder = finders.new_dynamic({
			fn = courses.getCoursesFinder(),
			entry_maker = function(entry)
				return {
					display = entry.display,
					ordinal = entry.display,
					course_id = entry.course_id,
					series = entry.series,
					teacher = entry.teacher,
					url = entry.url,
					year = entry.year,
				}
			end,
		}),
		sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
		attach_mappings = attach_course_mappings,
	}

	picker_helper.create_picker(opts)
end

-- Open search picker for activities
function M.searchActivities()
	local opts = {
		prompt_title = "Search Activities",
		finder = activities.getActivitiesFinder(),
		sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
		attach_mappings = attach_activity_mappings,
	}

	picker_helper.create_picker(opts)
end

return M
