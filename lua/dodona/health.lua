local M = {}

function M.check()
	vim.health.start("dodona.nvim")
	if vim.fn.has("nvim-0.10") == 1 then
		vim.health.ok("Neovim >= 0.10")
	else
		vim.health.error("Neovim >= 0.10 is required")
	end

	for module, plugin in pairs({
		["plenary.curl"] = "nvim-lua/plenary.nvim",
		["telescope.pickers"] = "nvim-telescope/telescope.nvim",
	}) do
		if pcall(require, module) then
			vim.health.ok(plugin .. " is available")
		else
			vim.health.error(plugin .. " is missing")
		end
	end

	if vim.fn.executable("curl") == 1 then
		vim.health.ok("curl is available")
	else
		vim.health.error("curl is required for downloads")
	end

	local token_path = vim.fn.stdpath("data") .. "/dodona/token"
	if vim.fn.filereadable(token_path) == 1 then
		vim.health.ok("API token is configured")
	else
		vim.health.warn("No API token found", { "Run :DodonaSetToken" })
	end
end

return M
