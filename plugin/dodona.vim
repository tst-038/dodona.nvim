if !has('nvim-0.5')
  echoerr 'You need neovim version >= 0.5 to run this plugin'
  finish
endif

command! DodonaSubmit lua require'dodona'.submit()
command! DodonaInit lua require'dodona'.initActivities()
command! DodonaSearchCourse lua require'dodona'.searchCourses()
command! DodonaSearchActivity lua require'dodona'.searchActivities()
command! DodonaDownload lua require'dodona'.download()
command! DodonaGo lua require'dodona'.go()
command! DodonaSetToken lua require'dodona'.setToken()
