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
    -- TODO, is there anyway to add autocomplete for git branches here?
    local success, worktree_name = pcall(function() return vim.fn.input(string.format("worktree:")) end)
    if (not success) then
        return
    end

    -- Check if git has the branch with this name already, otherwise checkout a feature branch
    -- Put new worktrees in git root dir
    local worktree_path = git.gitroot_dir() .. "/" .. worktree_name
    worktree.create_worktree(worktree_path, worktree_name)
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

Hooks.register(Hooks.type.SWITCH, function(path, prev_path)
    vim.notify("On Worktree " .. path)
    update_on_switch(path, prev_path)

    local updated_data = {
        current_worktree = path
    }

    if isWorktree(prev_path) then
        updated_data.previous_worktree = prev_path
    end

    state:update(updated_data)

    GitSubmoduleUpdate()
end)


Hooks.register(Hooks.type.DELETE, function()
    vim.cmd(config.update_on_change_command)
end)
