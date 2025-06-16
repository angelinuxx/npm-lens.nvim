-- Load plugin on package.json
local group = vim.api.nvim_create_augroup("npm-lens", { clear = true })

-- Init on neovim startup
vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  callback = function()
    require("npm-lens")._boot()
  end,
})

-- Sync virtual text on package.json open
vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  pattern = "package.json",
  callback = function()
    require("npm-lens")._sync_virtual_text()
  end,
})

-- Refresh on package.json save
vim.api.nvim_create_autocmd("BufWritePost", {
  group = group,
  pattern = "package.json",
  callback = function()
    -- Refresh func calls init if needed
    require("npm-lens").refresh()
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
