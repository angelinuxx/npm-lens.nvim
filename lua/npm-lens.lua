local M = {}

---@class nvim_lens.Options
---@field enable boolean: Whether the virtual text is enabled on startup
---@field status nvim_lens.Statuses: The statuses configuration for the plugin
---@field availableSection nvim_lens.AvailableSection: The available section configuration for the plugin

---@class nvim_lens.Statuses
---@field uptodate nvim_lens.StatusOptions: The configuration for the status when package is up to date
---@field wantedAvailable nvim_lens.StatusOptions: The configuration for the status when wanted version is available (and there is no newer version)
---@field newerAvailable nvim_lens.StatusOptions: The configuration for the status when newer version is available

---@class nvim_lens.StatusOptions
---@field label string: The label to show for this status
---@field hl vim.api.keyset.highlight: The highlight group config for this status

---@class nvim_lens.AvailableSection
---@field wantedLabel string: The label to show for the wanted version
---@field latestLabel string: The label to show for the latest version
---@field hl vim.api.keyset.highlight: The highlight group config for this section

---@class nvim_lens.Dependency
---@field linenr number: The line number where the dependency is written
---@field name string: The name of the package
---@field current string: The current installed version
---@field wanted string|nil: The wanted version
---@field latest string|nil: The latest version

---@class nvim_lens.State
---@field deps nvim_lens.Dependency[]: The list of dependencies
---@field show boolean: Whether the virtual text is shown
---@field nsid number: The namespace id for the virtual text
---@field bufnr number|nil: The buffer number
---@field startupCompleted boolean: Whether the startup has completed (means bufnr is set and deps are parsed)

---@type nvim_lens.Options
local defaults = {
	enable = true,
	status = {
		uptodate = { label = "󰄲", hl = { link = "DiagnosticUnnecessary" } },
		wantedAvailable = { label = "󰍵", hl = { link = "DiagnosticVirtualTextWarn" } },
		newerAvailable = { label = "󰀧", hl = { link = "DiagnosticVirtualTextError" } },
	},
	availableSection = {
		wantedLabel = "Wanted:",
		latestLabel = "Latest:",
		hl = { fg = "#6c7087" },
	},
}

--- Initialize the highlight groups
--- @param opts nvim_lens.Options
local init_highlight = function(opts)
	vim.api.nvim_set_hl(0, "NpmLensUptodate", opts.status.uptodate.hl)
	vim.api.nvim_set_hl(0, "NpmLensWantedAvailable", opts.status.wantedAvailable.hl)
	vim.api.nvim_set_hl(0, "NpmLensNewerAvailable", opts.status.newerAvailable.hl)
	vim.api.nvim_set_hl(0, "NpmLensAvailableVersions", opts.availableSection.hl)
	vim.api.nvim_set_hl(0, "NpmLensSeparators", { fg = "#9399b3" })
end

-- Initialize the default options, which can be overridden by the user through setup
-- or options passed in when using lazy.nvim
---@type nvim_lens.Options
local options = vim.tbl_deep_extend("force", defaults, {})
init_highlight(options)

--- Global plugin status
---@type nvim_lens.State
local state = {
	deps = {},
	show = options.enable,
	nsid = vim.api.nvim_create_namespace("npm-lens.nvim"),
	bufnr = nil,
	startupCompleted = false,
}

--- Plugin setup
M.setup = function(opts)
	options = vim.tbl_deep_extend("force", defaults, opts or {})
	init_highlight(options)
	state.show = options.enable
end

--- Retrieve data based on dep status
---@param dep nvim_lens.Dependency: The dependency
---@return string, string, boolean: The label, The highlight group, Whether the dependency is up to date
local get_status_vars = function(dep)
	local label = options.status.uptodate.label
	local hl_group = "NpmLensUptodate"
	local outdated = dep.latest ~= nil and dep.wanted ~= nil
	if outdated then
		if dep.wanted == dep.latest then
			label = options.status.wantedAvailable.label
			hl_group = "NpmLensWantedAvailable"
		else
			label = options.status.newerAvailable.label
			hl_group = "NpmLensNewerAvailable"
		end
	end

	return label, hl_group, outdated
end

--- Build the text for the available section
--- @param wanted string: The wanted version
--- @param latest string: The latest version
local build_available_text = function(wanted, latest)
	return options.availableSection.wantedLabel
		.. " "
		.. wanted
		.. " - "
		.. options.availableSection.latestLabel
		.. " "
		.. latest
end

-- Adds dependency virtual text
---@param deps nvim_lens.Dependency[]
local add_virtual_text = function(bufnr, deps)
	-- Define the virtual text to display
	for _, dep in ipairs(deps) do
		local label, hl_group, outdated = get_status_vars(dep)
		local virt_text = {
			{ label .. " " .. dep.current, hl_group },
		}
		if outdated then
			table.insert(virt_text, { "  ", "NpmLensSeparators" })
			table.insert(virt_text, { build_available_text(dep.wanted, dep.latest), "NpmLensAvailableVersions" })
		end
		-- Set the virtual text
		vim.api.nvim_buf_set_extmark(bufnr, state.nsid, dep.linenr, 0, {
			virt_text = virt_text,
			hl_mode = "combine",
		})
	end
end

--- Remove dependency virtual text
local remove_virtual_text = function(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, state.nsid, 0, -1)
end

local is_npm_file = function()
	local filename = vim.fn.expand("%:t")
	return filename == "package.json"
end

local refresh_virtual_text = function(bufnr)
	if state.show then
		remove_virtual_text(bufnr)
		add_virtual_text(bufnr, state.deps)
	end
end

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
					linenr = i - 1,
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
local add_deps_info = function(deps)
	-- exec `npm outdated --json`
	vim.system({ "npm", "outdated", "--json" }, { text = true }, function(outdated)
		-- add a sleep for debugging
		outdated = vim.json.decode(outdated.stdout)

		-- reconcile outdated with deps
		for _, dep in ipairs(deps) do
			local outdated_dep = outdated[dep.name]
			if outdated_dep then
				dep.current = outdated_dep.current
				dep.wanted = outdated_dep.wanted
				dep.latest = outdated_dep.latest
			end
		end
		state.deps = deps
		vim.schedule(function()
			refresh_virtual_text(state.bufnr)
		end)
	end)
end

local refresh_deps = function()
	-- parse package.json buffer using parse_buffer
	state.deps = parse_buffer(state.bufnr)
	refresh_virtual_text(state.bufnr)

	-- add version infos to dependencies table using `npm outdated`
	vim.notify("󱑢 Checking dependencies", vim.log.levels.INFO, { title = "NpmLens" })
	add_deps_info(state.deps)
end

--- Init plugin state
---@return boolean: Whether the plugin has been initialized
M._init = function()
	-- TODO: check if npm is installed

	-- check if current curren file is package.json
	if not is_npm_file() then
		vim.notify("Not a package.json file", vim.log.levels.WARN, { title = "NpmLens" })
		return false
	end

	if not state.startupCompleted then
		state.bufnr = vim.api.nvim_get_current_buf()
		refresh_deps()
		state.startupCompleted = true
	end

	return true
end

--- Toggle the virtual text
M.toggle = function()
	local firstTime = not state.startupCompleted
	-- The _init function is idempotent
	if M._init() then
		if firstTime then
			return
		end
		if state.show then
			remove_virtual_text(state.bufnr)
			state.show = false
		else
			add_virtual_text(state.bufnr, state.deps)
			state.show = true
		end
	end
end

--- Refresh deps info
M.refresh = function()
	local firstTime = not state.startupCompleted
	if M._init() then
		if not firstTime then
			refresh_deps()
		end
	end
end

return M
