local Job = require('plenary.job')


local M = {}

---@return boolean
function M.is_tmux_session()
    local job = Job:new {
        command = 'sh',
        args = { '-c', '[ -n \"$TMUX\" ]' },
        cwd = vim.loop.cwd(),
    }
    local _, ret = job:sync()
    return ret == 0
end

M.is_tmux_session()

---@return table, table
--- table of the inactive tmux windows indexes
--- table of cwd's of all inactive windows... in the same order as the first table.
function M.get_inactive_windows_and_cwds()
    local tmux_active = "ACTIVE"
    local inactive_windows = {}
    local inactive_cwds = {}

    local sep = ","
    local job = Job:new {
        command = 'tmux',
        args = { 'list-windows', '-F', string.format("#{window_index},#{?window_active,%s, },#{pane_current_path}", tmux_active) },
        cwd = vim.loop.cwd(),
        on_stdout = function(_, data, _)
            if data ~= nil then
                local tmux_out = {}
                for token in string.gmatch(data, '([^' .. sep .. ']+)') do
                    table.insert(tmux_out, token)
                end
                if #tmux_out ~= 3 then
                    -- TODO print out something
                    return
                end

                local window_idx = tmux_out[1]
                local active = tmux_out[2]
                local pane_cwd = tmux_out[3]
                if active ~= tmux_active then
                    table.insert(inactive_windows, window_idx)
                    table.insert(inactive_cwds, pane_cwd)
                end
            end
        end
    }

    local _, ret = job:sync()
    -- TODO HANDLE job error
    return inactive_windows, inactive_cwds
end

---@param window_idx number the index of the window to
---send the command to
---@param cmd string the command to run
---@return Job
function M.send_keys(window_idx, cmd)
    local job = Job:new {
        command = 'tmux',
        args = { 'send-keys', '-t', window_idx, cmd, "Enter" },
        cwd = vim.loop.cwd(),
    }
    job:start()
end

---@param window_idx number the index of the window
function M.get_window_cwd(window_idx)
    local job = Job:new {
        command = 'tmux',
        args = { 'list-panes', '-F', window_idx, cmd, "Enter" },
        cwd = vim.loop.cwd(),
    }
end

function M.change_session_cwds(prev_path, path)
    local inactive_windows, cwds = M.get_inactive_windows_and_cwds()
    for idx, window_idx in ipairs(inactive_windows) do
        if cwds[idx] == prev_path then
            M.send_keys(window_idx, string.format("cd %s", path))
            -- Clear shell
            M.send_keys(window_idx, "clear")
        end
    end
end

return M
