# `npm-lens.nvim`

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

The highlight of current changes based on the version state, by default as follows:

- `uptodate`: muted text and 󰄲 icon. The highlight group is linked to `DiagnosticUnnecessary`.
- `wantedAvailable`: warning text and 󰍵 icon. The highlight group is linked to `DiagnosticVirtualTextWarn`.
- `newerAvailable`: error text and 󰀧 icon. The highlight group is linked to `DiagnosticVirtualTextError`

---

## 📦 Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'angelinuxx/npm-lens.nvim',
  -- Optional: these are the default options
  opts = {
    enabled = true, -- If false, the info in `package.json` will not be displayed until `:NpmLensToggle` is called
    status = {
      uptodate = { icon = "󰄲" },
      wantedAvailable = { icon = "󰍵" },
      newerAvailable = { icon = "󰀧" },
    },
  },
}
```

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

- [ ] Configurable highlight groups for each version state
- [ ] Auto-load plugin only in Node.js projects (currently activates in `package.json` files only)
- [ ] Expose an API to get overall project dependency status:

  - Total number of dependencies
  - Number of outdated packages

- [ ] Integration with `lualine.nvim` to show dependency stats
