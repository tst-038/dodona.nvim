local M = {}

local modules = {
	getSubscribedCourses = "dodona.course.course",
	getSubscribedCoursesAsync = "dodona.course.course",
	getCourse = "dodona.course.course",
	subscribe = "dodona.course.course",
	getSeries = "dodona.course.series",
	getSeriesAsync = "dodona.course.series",
	getActivities = "dodona.course.activity",
	getActivitiesAsync = "dodona.course.activity",
	evalSubmission = "dodona.course.activity",
	evalSubmissionContent = "dodona.course.activity",
	getMediaFiles = "dodona.file.media",
	getMediaFilesAsync = "dodona.file.media",
	downloadToBuffer = "dodona.file.media",
}

for method, module in pairs(modules) do
	M[method] = function(...)
		return require(module)[method](...)
	end
end

return M
