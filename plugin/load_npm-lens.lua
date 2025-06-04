-- Load plugin on package.json
local group = vim.api.nvim_create_augroup("npm-lens", { clear = true })
for _, event in ipairs({ "BufReadPost", "BufWritePost" }) do
	vim.api.nvim_create_autocmd(event, {
		group = group,
		pattern = "package.json",
		callback = function()
			-- Refresh func calls init if needed
			require("npm-lens").refresh()
		end,
	})
end

-- Toggle command
vim.api.nvim_create_user_command("NpmLensToggle", function()
	require("npm-lens").toggle()
end, {})

-- Refresh command
vim.api.nvim_create_user_command("NpmLensRefresh", function()
	require("npm-lens").refresh()
end, {})
