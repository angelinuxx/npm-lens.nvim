local M = {}

---@class nvim_lens.Options
---@field show boolean: Whether the virtual text is enabled on startup
---@field status nvim_lens.Statuses: The statuses configuration for the plugin
---@field available_section nvim_lens.AvailableSection: The available section configuration for the plugin
---@field hide_notifications boolean: Whether the notifications should be hidden

---@class nvim_lens.Statuses
---@field uptodate nvim_lens.StatusOptions: The configuration for the status when package is up to date
---@field wanted_available nvim_lens.StatusOptions: The configuration for the status when wanted version is available (and there is no newer version)
---@field newer_available nvim_lens.StatusOptions: The configuration for the status when newer version is available

---@class nvim_lens.StatusOptions
---@field label string: The label to show for this status
---@field hl vim.api.keyset.highlight: The highlight group config for this status

---@class nvim_lens.AvailableSection
---@field wanted_label string: The label to show for the wanted version
---@field latest_label string: The label to show for the latest version
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
---@field startup_started boolean: Whether the startup has started, boot function is called
---@field startup_completed boolean: Whether the startup has completed (deps are parsed)
---@field package_json_path string|nil: The path to the package.json file

---@class nvim_lens.ParseCallbacks
---@field on_parse ?fun(deps: nvim_lens.Dependency[]): nil Runs after package.json is parsed
---@field on_complete ?fun(deps: nvim_lens.Dependency[]): nil Runs after npm outdated is parsed

---@type nvim_lens.Options
local defaults = {
  show = true,
  hide_notifications = false,
  status = {
    uptodate = { label = "󰄲", hl = { link = "DiagnosticUnnecessary" } },
    wanted_available = { label = "󰍵", hl = { link = "DiagnosticVirtualTextWarn" } },
    newer_available = { label = "󰀧", hl = { link = "DiagnosticVirtualTextError" } },
  },
  available_section = {
    wanted_label = "Wanted:",
    latest_label = "Latest:",
    hl = { fg = "#6c7087" },
  },
}

--- Initialize the highlight groups
--- @param opts nvim_lens.Options
local init_highlight = function(opts)
  vim.api.nvim_set_hl(0, "NpmLensUptodate", opts.status.uptodate.hl)
  vim.api.nvim_set_hl(0, "NpmLensWantedAvailable", opts.status.wanted_available.hl)
  vim.api.nvim_set_hl(0, "NpmLensNewerAvailable", opts.status.newer_available.hl)
  vim.api.nvim_set_hl(0, "NpmLensAvailableVersions", opts.available_section.hl)
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
  show = options.show,
  nsid = vim.api.nvim_create_namespace "npm-lens.nvim",
  startup_started = false,
  startup_completed = false,
  package_json_path = nil,
}

local root_file = "package.json"

--- Plugin setup
M.setup = function(opts)
  options = vim.tbl_deep_extend("force", defaults, opts or {})
  init_highlight(options)
  state.show = options.show
end

--- Try to detect the project root
--- @return string
local get_node_project_root = function()
  local cwd = vim.fn.getcwd()

  local result = vim.fs.find(root_file, {
    upward = true,
    path = cwd,
    stop = vim.loop.os_homedir(),
  })

  return result[1] and vim.fs.dirname(result[1]) or nil
end

--- Try to detect the project root
--- @return boolean
local try_node_detect = function()
  local root = get_node_project_root()
  if root then
    state.package_json_path = root .. "/" .. root_file
    return true
  end

  return false
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
      label = options.status.wanted_available.label
      hl_group = "NpmLensWantedAvailable"
    else
      label = options.status.newer_available.label
      hl_group = "NpmLensNewerAvailable"
    end
  end

  return label, hl_group, outdated
end

--- Build the text for the available section
--- @param wanted string: The wanted version
--- @param latest string: The latest version
local build_available_text = function(wanted, latest)
  return options.available_section.wanted_label
    .. " "
    .. wanted
    .. " - "
    .. options.available_section.latest_label
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

local refresh_virtual_text = function(bufnr)
  if state.show then
    remove_virtual_text(bufnr)
    add_virtual_text(bufnr, state.deps)
  end
end

--- Reads all lines of a file into a table, without loading a buffer
---@param filepath string: absolute path to file
---@return string[]: table of lines
local read_lines = function(filepath)
  local f = io.open(filepath, "r")
  if not f then
    return {}
  end

  local lines = {}
  for line in f:lines() do
    table.insert(lines, line)
  end
  f:close()
  return lines
end

---Parse lines
---@param lines string[]
---@return nvim_lens.Dependency[]
local parse_lines = function(lines)
  local deps = {}
  local isDep = false -- Flag to indicate if we are in a dependency sections
  for i, line in ipairs(lines) do
    -- Trim whitespace from the line
    line = line:gsub("^%s*(.-)%s*$", "%1") -- Trim leading and trailing whitespace
    if isDep then
      -- Match lines that look like `"package-name": "version"`
      local name, version = line:match '"(.+)"%s*:%s*"(.-)"'
      if name and version then
        table.insert(deps, {
          name = name,
          current = version:gsub("%^", ""):gsub("~", ""),
          linenr = i - 1,
        })
      end
    end
    -- Check if we are in the dependencies or devDependencies section
    if line:match '"dependencies"%s*:%s*{' or line:match '"devDependencies"%s*:%s*{' then
      isDep = true
    elseif line:match "}" then
      isDep = false
    end
  end

  return deps
end

---@param path string: The path to the package.json
---@return nvim_lens.Dependency[]: The list of dependencies
local parse_file = function(path)
  -- Read the contents of the file
  local lines = read_lines(path)
  -- local lines = vim.api.nvim_buf_get_lines(bfnr, 0, -1, false)
  if #lines == 0 then
    return {}
  end

  local deps = parse_lines(lines)

  return deps
end

--- Parse the npm outdated json output
--- @param deps nvim_lens.Dependency[]
--- @param outdated table
--- @return nvim_lens.Dependency[]
local parse_npm_outdated = function(deps, outdated)
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

--- Exec `npm outdated --json` asynchronously and call the on_complete function with the result
---@param on_complete function: The function to call when the npm outdated command is completed, passing the outdated table
local retrieve_npm_outdated = function(on_complete)
  vim.system({ "npm", "outdated", "--json" }, { text = true }, function(outdated)
    outdated = vim.json.decode(outdated.stdout)
    on_complete(outdated)
  end)
end

--- Refresh the dependencies and call the callbacks
---@param callbacks ?nvim_lens.ParseCallbacks: Table of callbacks
local refresh_deps = function(callbacks)
  -- parse package.json buffer using parse_buffer
  state.deps = parse_file(state.package_json_path)
  if callbacks and callbacks.on_parse then
    callbacks.on_parse(state.deps)
  end

  -- Notify checking dependencies only in package.json
  local bufnr = vim.api.nvim_get_current_buf()
  if not options.hide_notifications and vim.api.nvim_buf_get_name(bufnr) == state.package_json_path then
    vim.notify("󱑢 Checking dependencies", vim.log.levels.INFO, { title = "NpmLens" })
  end
  retrieve_npm_outdated(function(outdated)
    state.deps = parse_npm_outdated(state.deps, outdated)
    if callbacks and callbacks.on_complete then
      callbacks.on_complete(state.deps)
    end
  end)
end

--- Bootstrap plugin state. This function is idempotent
---@param callbacks ?nvim_lens.ParseCallbacks
---@return boolean: Whether the startup process has completed.
local boot = function(callbacks)
  if not state.startup_started then
    state.startup_started = true
    if not try_node_detect() then
      return false
    end

    if not options.hide_notifications then
      vim.notify("󱑢 Node detected", vim.log.levels.INFO, { title = "NpmLens" })
    end

    refresh_deps(callbacks)
  end
  return state.startup_completed
end

local parser_callbacks = {
  on_complete = function()
    state.startup_completed = true
    vim.schedule(function()
      -- on_complete we are sure that package_json_path is set
      local bufnr = vim.api.nvim_get_current_buf()
      if vim.api.nvim_buf_get_name(bufnr) == state.package_json_path then
        refresh_virtual_text(bufnr)
      end
    end)
  end,
}

--- Bootstraps the plugin,
M._boot = function()
  return boot(parser_callbacks)
end

M._sync_virtual_text = function()
  local bufnr = vim.api.nvim_get_current_buf()
  if state.startup_completed and vim.api.nvim_buf_get_name(bufnr) == state.package_json_path then
    refresh_virtual_text(bufnr)
  end
end

--- Refresh deps info
M.refresh = function()
  -- If the plugin is not started (e.g. lazy loaded), then boot
  if not state.startup_started then
    boot(parser_callbacks)
    return
  end

  -- If the startup is already in progress, do nothing
  if not state.startup_completed then
    return
  end

  refresh_deps(parser_callbacks)
end

--- Toggle the virtual text, runs only if package.json is the open buffer
M.toggle = function()
  -- If the plugin is not started (e.g. lazy loaded), then boot
  if not state.startup_started then
    boot(parser_callbacks)
    return
  end

  -- If the startup is already in progress, do nothing
  if not state.startup_completed then
    return
  end

  -- If the current buffer is not package.json, do nothing
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_name(bufnr) ~= state.package_json_path then
    vim.notify("  Not in package.json", vim.log.levels.INFO, { title = "NpmLens" })
    return
  end

  if state.show then
    remove_virtual_text(bufnr)
    state.show = false
  else
    add_virtual_text(bufnr, state.deps)
    state.show = true
  end
end

--- Exposing for testing
M._parse_lines = parse_lines
M._parse_npm_outdated = parse_npm_outdated

return M
