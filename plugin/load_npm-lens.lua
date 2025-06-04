-- Load plugin on package.json
vim.api.nvim_create_autocmd("BufReadPost", {
	group = vim.api.nvim_create_augroup("npm-lens.init", { clear = true }),
	pattern = "package.json",
	callback = function()
		require("npm-lens")._init()
	end,
})

-- Toggle command
vim.api.nvim_create_user_command("NpmLensToggle", function()
	require("npm-lens").toggle()
end, {})

-- Refresh command
vim.api.nvim_create_user_command("NpmLensRefresh", function()
	require("npm-lens").refresh()
end, {})
