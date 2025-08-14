-- vim.g.git_worktree_log_level = "debug"
local worktree = require("git-worktree")
local git = require("git-worktree.git")
local Job = require('plenary.job')

local harpoon_path = require "harpoon.path"
local harpoon_default_list = require "harpoon.config".DEFAULT_LIST
local harpoon_config = require "harpoon.config"
local harpoon_data = require "harpoon.data"

local last_worktree = nil

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

vim.keymap.set("n", "<leader>wl", function()
    -- Switches to your last worktree
    if last_worktree ~= nil then
        worktree.switch_worktree(last_worktree)
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

local function IsWorktree(path)
    return not (git.gitroot_dir() == path)
end

local function GetHarpoonData(path)
    -- This succesfully reads our data first but then fails subsequently
    local data = harpoon_data.Data:new(harpoon_config:get_default_config())
    return data:data(path, harpoon_default_list)
end

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

    -- Hack to get arround strange harpoon behaviour
    -- Harpoon is not reloading its data upon the current_directory of nvim being changed
    -- Simply reloading the plugin gets around this... had initially tried digging into harpoon
    -- itself but its a fucking mess.
    ReloadLazyPlugin("harpoon2")

    last_worktree = prev_path
    GitSubmoduleUpdate()
    update_on_switch(path, prev_path)

    -- Say that we've moved between worktrees if both path and prev_path are not worktrees
    if IsWorktree(prev_path) and IsWorktree(path) then
        -- Once we've moved between worktrees, we want to logically move the harpoon
        -- list of one worktree to another.
        -- This involves tampering with harpoons actual underlying in the new worktrees directory.
        local prev_data = GetHarpoonData(prev_path)
        if vim.tbl_isempty(prev_data) then
            -- Nothing to do
            return
        end

        local next_data = GetHarpoonData(path)

        if vim.tbl_isempty(next_data) then
            -- Add all entries of prev_data into next_data, replacing paths
            for _, value in ipairs(prev_data) do
            end
        end
    end
end)


Hooks.register(Hooks.type.DELETE, function()
    vim.cmd(config.update_on_change_command)
end)
