-- vim.g.git_worktree_log_level = "debug"
local worktree = require("git-worktree")
local git = require("git-worktree.git")
local Job = require('plenary.job')

-- Keybindings
vim.keymap.set("n", "<leader>wa", function()
    local success, worktree_name = pcall(function() return vim.fn.input(string.format("worktree:")) end)
    if (not success) then
        return
    end
    local branch_name = string.format("feat/%s", worktree_name)

    -- Put new worktrees in git root dir
    local worktree_path = git.gitroot_dir() .. "/" .. worktree_name
    worktree.create_worktree(worktree_path, branch_name)
end)

vim.keymap.set("n", "<leader>ws", function()
    local telescope_worktree = require('telescope').load_extension("git_worktree")
    telescope_worktree.git_worktree()
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

-- Switch current active buffers when changing between worktrees
-- TODO: update harpoon entries as well, only if that file actually exists though
Hooks.register(Hooks.type.SWITCH, function(path, prev_path)
    vim.notify("Moved from " .. prev_path .. " to " .. path)
    GitSubmoduleUpdate()
    update_on_switch(path, prev_path)
end)


Hooks.register(Hooks.type.DELETE, function()
    vim.cmd(config.update_on_change_command)
end)
