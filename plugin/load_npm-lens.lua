-- Toggle command
vim.api.nvim_create_user_command("NpmLensToggle", function()
	require("npm-lens").toggle()
end, {})
