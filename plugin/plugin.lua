-- vim.g.git_worktree_log_level = "debug"
local worktree = require("git-worktree")
local git = require("git-worktree.git")
local Job = require('plenary.job')
local state = require("git-worktree.state")

local function isWorktree(path)
    return not (git.gitroot_dir() == path)
end

-- Load state and load the current_worktree if there is one saved
local state_current_worktree = state:data().current_worktree
if state_current_worktree then
    worktree.switch_worktree(state_current_worktree)
end


-- Keybindings
vim.keymap.set("n", "<leader>wa", function()
    local success, worktree_name = pcall(function() return vim.fn.input(string.format("worktree:")) end)
    if (not success) then
        return
    end

    local branch_name
    if git.has_branch(worktree) then
        branch_name = worktree
    else
        branch_name = string.format("feat/%s", worktree_name)
    end

    -- Put new worktrees in git root dir
    local worktree_path = git.gitroot_dir() .. "/" .. worktree_name
    worktree.create_worktree(worktree_path, branch_name)
end)

vim.keymap.set("n", "<leader>ws", function()
    local telescope_worktree = require('telescope').load_extension("git_worktree")
    telescope_worktree.git_worktree()
end)

vim.keymap.set("n", "<leader>wl", function()
    local previous_worktrree = state:data().previous_worktree
    -- Switches to your last worktree
    if previous_worktrree ~= nil and isWorktree(previous_worktrree) then
        worktree.switch_worktree(previous_worktrree)
    else
        print("no previous worktree")
    end
end)

-- Hooks

local Hooks = require("git-worktree.hooks")
local config = require('git-worktree.config')
local update_on_switch = Hooks.builtins.update_current_buffer_on_switch

local function GitSubmoduleUpdate()
    ---@diagnostic disable-next-line
    local job = Job:new({
        command = 'git',
        args = { 'submodule', 'update', '--init', '--recursive' }
    })
end

-- local function GetHarpoonData(path)
--     -- This succesfully reads our data first but then fails subsequently
--     local data = harpoon_data.Data:new(harpoon_config:get_default_config())
--     return data:data(path, harpoon_default_list)
-- end

local function ReloadLazyPlugin(plugin_name)
    local plugin = require("lazy.core.config").plugins[plugin_name]
    if plugin then
        package.loaded[plugin] = nil
        require("lazy.core.loader").reload(plugin)
    else
        print(plugin_name .. "not reloaded")
    end
end

-- So harpoon does not seem to read in new data on the directory changing for some reason?
-- Switch current active buffers when changing between worktrees
Hooks.register(Hooks.type.SWITCH, function(path, prev_path)
    vim.notify("On Worktree " .. path)

    local updated_data = {
        current_worktree = path
    }

    if isWorktree(prev_path) then
        updated_data.previous_worktree = prev_path
    end

    state:update(updated_data)

    -- Hack to get arround strange harpoon behaviour
    -- Harpoon is not reloading its data upon the current_directory of nvim being changed
    -- Simply reloading the plugin gets around this... had initially tried digging into harpoon
    -- itself but its a fucking mess.
    ReloadLazyPlugin("harpoon2")

    GitSubmoduleUpdate()
    update_on_switch(path, prev_path)
end)


Hooks.register(Hooks.type.DELETE, function()
    vim.cmd(config.update_on_change_command)
end)
