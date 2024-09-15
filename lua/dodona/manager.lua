local course = require("dodona.course.course")
local series = require("dodona.course.series")
local activity = require("dodona.course.activity")
local media = require("dodona.file.media")

local M = {}

-- Course management
M.getSubscribedCourses = course.getSubscribedCourses
M.getCourse = course.getCourse
M.subscribe = course.subscribe

-- Series management
M.getSeries = series.getSeries

-- Activity management
M.getActivities = activity.getActivities
M.evalSubmission = activity.evalSubmission

-- Media and file handling
M.getMediaFiles = media.getMediaFiles
M.downloadToBuffer = media.downloadToBuffer

return M
