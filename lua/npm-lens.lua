local M = {}

-- TODO: make this configurable
local init_highlight = function()
	vim.api.nvim_set_hl(0, "NpmLensLatest", { link = "DiagnosticUnnecessary" })
	vim.api.nvim_set_hl(0, "NpmLensOutdatedMinor", { link = "DiagnosticVirtualTextWarn" })
	vim.api.nvim_set_hl(0, "NpmLensOutdated", { link = "DiagnosticVirtualTextError" })
	vim.api.nvim_set_hl(0, "NpmLensAvailable", { link = "DiagnosticVirtualTextInfo" })
end

local defaults = {
	status = {
		latest = { icon = "󰄲" },
		outdated = { icon = "󰀧" },
		outdatedMinor = { icon = "󰍵" },
	},
}

---@class nvim_lens.Options
---@field status nvim_lens.Statuses: The statuses configuration for the plugin

---@class nvim_lens.Statuses
---@field latest nvim_lens.StatusOptions?: The configuration for the latest status
---@field outdated nvim_lens.StatusOptions?: The configuration for the outdated status
---@field outdatedMinor nvim_lens.StatusOptions?: The configuration for the outdated minor status
---
---@class nvim_lens.StatusOptions
---@field icon string?: The icon to show for this status

---@type nvim_lens.Options
local options = vim.tbl_deep_extend("force", defaults, {})
init_highlight()

--- Plugin setup
M.setup = function(opts)
	options = vim.tbl_deep_extend("force", defaults, opts or {})
end

---@class nvim_lens.Dependency
---@field line_nr number: The line number where the dependency is written
---@field name string: The name of the package
---@field current string: The current installed version
---@field wanted string|nil: The wanted version
---@field latest string|nil: The latest version

---@param bfnr number
---@return nvim_lens.Dependency[]: The list of dependencies
local parse_buffer = function(bfnr)
	-- Read the contents of the buffer
	local lines = vim.api.nvim_buf_get_lines(bfnr, 0, -1, false)
	if #lines == 0 then
		return {}
	end

	-- Cause we have to keep the line number were dependency is written in buffer we need to loop over the buffer lines
	-- and build the deps table
	local deps = {}
	local isDep = false -- Flag to indicate if we are in a dependency sections
	for i, line in ipairs(lines) do
		-- Trim whitespace from the line
		line = line:gsub("^%s*(.-)%s*$", "%1") -- Trim leading and trailing whitespace
		if isDep then
			-- Match lines that look like `"package-name": "version"`
			local name, version = line:match('"(.+)"%s*:%s*"(.-)"')
			if name and version then
				table.insert(deps, {
					name = name,
					current = version:gsub("%^", ""):gsub("~", ""),
					line_nr = i - 1,
				})
			end
		end
		-- Check if we are in the dependencies or devDependencies section
		if line:match('"dependencies"%s*:%s*{') or line:match('"devDependencies"%s*:%s*{') then
			isDep = true
		elseif line:match("}") then
			isDep = false
		end
	end

	return deps
end

--- Takes a list of dependencies and add all the version infos (current, wanted, latest)
---@param deps nvim_lens.Dependency[]
---@return nvim_lens.Dependency[]
local add_deps_info = function(deps)
	-- exec `npm outdated --json`
	local outdated = vim.fn.system("npm outdated --json")
	outdated = vim.json.decode(outdated)

	-- reconcile outdated with deps
	for _, dep in ipairs(deps) do
		local outdated_dep = outdated[dep.name]
		if outdated_dep then
			dep.current = outdated_dep.current
			dep.wanted = outdated_dep.wanted
			dep.latest = outdated_dep.latest
		end
	end

	return deps
end

-- Function to add virtual text
---@param deps nvim_lens.Dependency[]
local add_virtual_text = function(deps)
	-- Create a namespace for the extmark
	local ns_id = vim.api.nvim_create_namespace("npm-lens.nvim")
	local bufnr = vim.api.nvim_get_current_buf()
	-- Define the virtual text to display
	for _, dep in ipairs(deps) do
		local icon = options.status.latest.icon
		local hl_group = "NpmLensLatest"
		local available = "󰏕 "
		local outdated = dep.latest ~= nil and dep.wanted ~= nil
		if outdated then
			available = available .. dep.wanted
			if dep.wanted ~= dep.latest then
				icon = options.status.outdated.icon
				hl_group = "NpmLensOutdated"
				available = available .. "  󰎔 " .. dep.latest
			else
				icon = options.status.outdatedMinor.icon
				hl_group = "NpmLensOutdatedMinor"
			end
		end

		local virt_text = {
			-- { " ", "NpmLensLatest" },
			{ icon .. " " .. dep.current, hl_group },
		}
		if outdated then
			table.insert(virt_text, { "  ", "NpmLensLatest" })
			table.insert(virt_text, { available, "NpmLensAvailable" })
		end
		-- Set the virtual text
		vim.api.nvim_buf_set_extmark(bufnr, ns_id, dep.line_nr, 0, {
			virt_text = virt_text,
			hl_mode = "combine",
		})
	end
end

---
M.toggle = function()
	-- check if current curren file is package.json
	-- TODO: in future i want to check in cwd and preload npm outdated info
	local filename = vim.fn.expand("%:t")
	if filename ~= "package.json" then
		vim.notify("Not a package.json file", vim.log.levels.WARN)
		return
	end

	-- TODO: check if npm is installed
	-- parse package.json buffer using parse_buffer
	local deps = parse_buffer(vim.api.nvim_get_current_buf())
	-- add version infos to dependencies table using npm_outdated
	deps = add_deps_info(deps)

	add_virtual_text(deps)

	return deps
end

return M
