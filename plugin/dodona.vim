if !has('nvim-0.10')
  echoerr 'dodona.nvim requires Neovim >= 0.10'
  finish
endif

command! DodonaSubmit lua require'dodona'.submit()
command! DodonaInit lua require'dodona'.initActivities()
command! DodonaInitActivities lua require'dodona'.initActivities()
command! DodonaSearch lua require'dodona'.search()
command! DodonaDownload lua require'dodona'.download()
command! DodonaGo lua require'dodona'.go()
command! DodonaSetToken lua require'dodona'.setToken()
command! DodonaCancel lua require'dodona'.cancel()
command! DodonaClearCache lua require'dodona'.clearCache()
