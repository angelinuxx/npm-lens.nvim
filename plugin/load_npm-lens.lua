-- Load plugin on package.json
local group = vim.api.nvim_create_augroup("npm-lens", { clear = true })
vim.api.nvim_create_autocmd("BufReadPost", {
	group = group,
	pattern = "package.json",
	callback = function()
		require("npm-lens").init()
	end,
})

-- Toggle command
vim.api.nvim_create_user_command("NpmLensToggle", function()
	require("npm-lens").toggle()
end, {})
