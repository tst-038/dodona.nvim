-- TODO: refractor, always get comment via extension
local M = {
  java = "//",
  python = "#",
  haskell = "--",
  c = "//",
  prolog = "% ",
  bash = "#",
  sh = "#",
  javascript = "//",
  text = "#",
}

local translate = {
  java = "java",
  py = "python",
  hs = "haskell",
  c = "c",
  pl = "prolog",
  sh = "sh",
  js = "javascript",
  txt = "text",
}

function M.comment_by_extension(extension)
  local language = translate[extension] or extension
  return M[language]
end

return M
