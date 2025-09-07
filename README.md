## What i've added to the original plugin 
- My additions are in the form of an opinionated out-of-the-box configuration and statefulness.
- git-worktree.nvim did not come with any keybindings configured, it just gave you the power 
  to make nice neovim workflows with worktreees. I have yieleded this power and made a 100 line lua configuration
  with it - all in [plugin.lua](./plugin/plugin.lua). This configuration is loaded on neovim startup.
- Stateful: current and previous worktrees persisted outside of neovim.
- Tmux integration: changing CWDs of windows when we switch worktrees.

Keymaps:
- `<leader>wa` prompts you for a worktree name, creates a worktree with that name and switches you to that worktree.
- `<leader>ws` to load telescope picker... within this picker `<C-d>` deletes
an entry, `<CR>` selects an entry and switches you to that workspace, `<C-f>`
force deletes an entry.
- `<leader>wl` to go to the previous workspace, if one exists.
  - This is achieved by adding persistent state to the plugin as detailed below.

Git Submodules are automatically updated on changing between worktrees.

**Worktree state is persisted between sessions. That is, the current and previous worktrees are remembered**
- If you close neovim whilst in a worktree, you will go back into that worktree on neovim restarting.
- Alternate/previous sessions are also persisted.

This workflow all works perfectly with harpoon... you can have separate harpoon lists on a per-worktree basis making worktrees a breeze to work with.
- you want to make a small change on your last worktree? hit `<leader>wl`, harpoon your way to the file, perform the change, `<leader>wl` and you are back
  where you started.

<!-- markdownlint-disable -->

![git-worktree.nvim](https://socialify.git.ci/polarmutex/git-worktree.nvim/image?font=Source%20Code%20Pro&name=1&stargazers=1&theme=Dark)

[![Neovim][neovim-shield]][neovim-url]
[![Lua][lua-shield]][lua-url]
[![Nix][nix-shield]][nix-url]

<!-- markdownlint-restore -->
A simple wrapper around git worktree operations, create, switch, and delete.
There is some assumed workflow within this plugin, but pull requests are
welcomed to fix that).

## Quick Links

## Prerequisites

### Required

-   `neovim >= 0.9`
-   `plenary.nvim`

### Optional

-   [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim)

## Installation

```lua
{
  '13janderson/git-worktree.nvim',
  version = '^2',
  dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim"}
}
```

## Quick Setup

This plugin does not require to call setup function, everything comes pre-configured in an opionated way, this configuration is loaded on neovim startup. See [plugin](./plugin/plugin.lua).

```

## Base Features

## Usage

Three primary functions should cover your day-to-day.

The path can be either relative from the git root dir or absolute path to the worktree.

```lua
-- Creates a worktree.  Requires the path, branch name, and the upstream
-- Example:
require("git-worktree").create_worktree("feat-69", "master", "origin")

-- switches to an existing worktree.  Requires the path name
-- Example:
require("git-worktree").switch_worktree("feat-69")

-- deletes to an existing worktree.  Requires the path name
-- Example:
require("git-worktree").delete_worktree("feat-69")
```


## Advanced Configuration

to modify the default configuration, set `vim.g.git_worktree`.

-   See [`:help git-worktree.config`](./doc/git-worktree.txt) for a detailed
    documentation of all available configuration options.

```lua
vim.g.git_worktree = {
    ...
}
```

### Hooks

Yes! The best part about `git-worktree` is that it emits information so that you
can act on it.

```lua
local Hooks = require("git-worktree.hooks")

Hooks.register(Hooks.type.SWITCH, Hooks.builtins.update_current_buffer_on_switch)
```

> [!IMPORTANT]
>
> -   **no** builtins are registered
>     by default and will have to be registered

This means that you can use [harpoon](https://github.com/ThePrimeagen/harpoon)
or other plugins to perform follow up operations that will help in turbo
charging your development experience!

### Telescope Config<a name="telescope-config"></a>

In order to use [Telescope](https://github.com/nvim-telescope/telescope.nvim) as a UI,
make sure to add `telescope` to your dependencies and paste this following snippet into your configuration.

```lua
require('telescope').load_extension('git_worktree')
```

### Debugging<a name="debugging"></a>

git-worktree writes logs to a `git-worktree-nvim.log` file that resides in Neovim's cache path. (`:echo stdpath("cache")` to find where that is for you.)

By default, logging is enabled for warnings and above. This can be changed by setting `vim.g.git_worktree_log_level` variable to one of the following log levels: `trace`, `debug`, `info`, `warn`, `error`, or `fatal`. Note that this would have to be done **before** git-worktree's `setup` call. Alternatively, it can be more convenient to launch Neovim with an environment variable, e.g. `> GIT_WORKTREE_NVIM_LOG=trace nvim`. In case both, `vim.g` and an environment variable are used, the log level set by the environment variable overrules. Supplying an invalid log level defaults back to warnings.

### Troubleshooting<a name="troubleshooting"></a>

If the upstream is not setup correctly when trying to pull or push, make sure the following command returns what is shown below. This seems to happen with the gitHub cli.

```lua
git config --get remote.origin.fetch

+refs/heads/*:refs/remotes/origin/*
```

if it does not run the following

```bash
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
```

<!-- MARKDOWN LINKS & IMAGES -->

[neovim-shield]: https://img.shields.io/badge/NeoVim-%2357A143.svg?&style=for-the-badge&logo=neovim&logoColor=white
[neovim-url]: https://neovim.io/
[lua-shield]: https://img.shields.io/badge/lua-%232C2D72.svg?style=for-the-badge&logo=lua&logoColor=white
[lua-url]: https://www.lua.org/
[nix-shield]: https://img.shields.io/badge/nix-0175C2?style=for-the-badge&logo=NixOS&logoColor=white
[nix-url]: https://nixos.org/
[luarocks-shield]: https://img.shields.io/luarocks/v/MrcJkb/haskell-tools.nvim?logo=lua&color=purple&style=for-the-badge
[luarocks-url]: https://luarocks.org/modules/polarmutex/git-worktree.nvim
