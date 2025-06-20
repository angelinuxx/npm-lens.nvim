# `npm-lens.nvim`

![npm-lens](./docs/preview.png)

A lightweight Neovim plugin that shows the status of dependencies in your
`package.json` file. Nothing more, nothing less.

I created this plugin to quickly see the current and available versions of npm
packages—without running `npm outdated` and manually grepping the results. For
adding, updating, or removing packages, I prefer using the terminal. If you're
looking for a plugin that handles those tasks, check out [package-info.nvim](https://github.com/vuki656/package-info.nvim).

> ⚠️ This is my first Neovim plugin. Feedback on code quality and performance
> is very welcome! I'm still learning Lua and the Neovim plugin ecosystem.

---

## ✨ Features

Displays version info as virtual text next to each dependency:

- **Current**: The installed version.
- **Wanted**: The latest version that satisfies the semver range in `package.json`.
- **Latest**: The absolute latest version available on the npm registry.

The highlight of **Current** is based on the version state, by default as follows:

- `uptodate`: muted text and 󰄲 icon as label. The highlight group is linked to `DiagnosticUnnecessary`.
- `wantedAvailable`: warning text and 󰍵 icon as label. The highlight group is
  linked to `DiagnosticVirtualTextWarn`.
- `newerAvailable`: error text and 󰀧 icon as label. The highlight group is
  linked to `DiagnosticVirtualTextError`

---

## 📦 Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'angelinuxx/npm-lens.nvim',

  -- Optional: these are the default options, you should define only the ones
  -- you want to change because they will be merged with the default ones
  opts = {
    enabled = true, -- If false, info in `package.json` won't display until `:NpmLensToggle` is used
    hide_notifications = false,
    status = {
      uptodate = {
        label = "󰄲",
        hl = { link = "DiagnosticUnnecessary" }
      },
      wantedAvailable = {
        label = "󰍵",
        hl = { link = "DiagnosticVirtualTextWarn" }
      },
      newerAvailable = {
        label = "󰀧",
        hl = { link = "DiagnosticVirtualTextError" }
      },
    },
    availableSection = {
      wantedLabel = "Wanted:",
      latestLabel = "Latest:",
      hl = { fg = "#6c7087" }
    }
  },
}
```

> ℹ️ You can pass any valid parameter from `vim.api.keyset.highlight` to the
> `hl` field.

The plugin loads packages information when opening/saving a `package.json` file.
But if you lazy load it (e.g. defining keys in lazy.nvim config), the
information will not be loaded until an available command is used.

---

## 🚀 Usage

Use the command `:NpmLensToggle` to toggle virtual text display in `package.json`.  
Use the command `:NpmLensRefresh` to trigger a refresh of the dependencies info.

---

### 🙏 Acknowledgements

- [Advent of Neovim](https://www.youtube.com/playlist?list=PLep05UYkc6wTyBe7kPjQFWVXTlhKeQejM) video series by [TJ Devries](https://github.com/tjdevries)
- Inspiration from [package-info.nvim](https://github.com/vuki656/package-info.nvim)

---

#### 🧭 Roadmap

- [x] Configurable highlight groups for each version state
- [x] Make the `Available` section labels (`Wanted` and `Latest`) and highlight group configurable
- [x] Auto-load the plugin only in Node.js projects (currently activates in `package.json` files only)
- [ ] Add a dependency audit feature and show vulnerable packages
- [ ] Show a vulnerability summary in a floating/split window
- [ ] Expose an API to get overall project dependency stats:
  - Total number of dependencies
  - Number of outdated packages
  - Number of vulnerable packages
- [ ] Integrate with `lualine.nvim` to show dependency stats

##### Known issues

- The current version may be wrong if the dependency is up to date because `npm outdated` doesn't return it. In this case, we show the semver without `^` or `*`. This will be fixed soon.
