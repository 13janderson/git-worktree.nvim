local Path = require "plenary.path"
local git = require("git-worktree.git")

---@class WorktreeData
---@field previous_worktree ?string
---@field current_worktree ?string

---@class WorktreeState
---@field _data WorktreeData
local WorktreeState = {}

---@return WorktreeState
function WorktreeState:new()
    self.__index = self

    local state = setmetatable({}, self)
    state._data = state:read() or {
        previous_workree = nil,
        current_worktree = nil,
    }

    return state
end

---@return Path | nil
function WorktreeState:path()
    local git_dir = git:gitroot_dir()

    if git_dir ~= nil then
        return Path:new(string.format("%s/%s/%s.json", vim.fn.stdpath("data"), "git-worktree.nvim",
            vim.fn.sha256(git_dir)))
    end

    return nil
end

---@return WorktreeData | nil
function WorktreeState:read()
    local path = self:path()
    if path ~= nil and path:exists() then
        return vim.fn.json_decode(Path:new(path):read())
    end

    return nil
end

---@return WorktreeData
function WorktreeState:data()
    return self._data
end

function WorktreeState:write()
    local path = Path:new(self:path())
    path:parent():mkdir({ parents = true, exists_ok = true })
    path:write(vim.fn.json_encode(self._data), "w")
end

---@param new_data WorktreeData
function WorktreeState:update(new_data)
    self._data = vim.tbl_deep_extend("force", self._data, new_data)
    self:write()
end

local theWorktreeState = WorktreeState:new()

return theWorktreeState
