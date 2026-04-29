local Job = require('plenary.job')

local M = {}

---@return boolean
function M.is_tmux_session()
    local job = Job:new {
        command = 'sh',
        args = { '-c', '[ -n "$TMUX" ]' },
        cwd = vim.loop.cwd(),
    }
    local _, ret = job:sync()
    return ret == 0
end

M.is_tmux_session()

---Check if a pane is running only the default shell
---@param command string the current command in the pane
---@return boolean true if the pane is running just a shell
local function is_shell_only(command)
    local default_shell = vim.env.SHELL
    if not default_shell then
        -- Cannot determine shell, be conservative and don't change CWD
        return false
    end
    local shell_name = default_shell:match('([^/]+)$')
    local cmd_name = command:match('([^/]+)$') or command
    return cmd_name == shell_name
end

---@return table, table, table
--- table of the inactive tmux pane IDs
--- table of cwd's of all inactive panes... in the same order as the first table.
--- table of commands of all inactive panes... in the same order as the first table.
function M.get_inactive_panes_and_cwds()
    local tmux_active = 'ACTIVE'
    local inactive_panes = {}
    local inactive_cwds = {}
    local inactive_commands = {}

    local sep = ','
    local job = Job:new {
        command = 'tmux',
        args = {
            'list-panes',
            '-a',
            '-F',
            string.format('#{pane_id},#{?pane_active,%s, },#{pane_current_path},#{pane_current_command}', tmux_active),
        },
        cwd = vim.loop.cwd(),
        on_stdout = function(_, data, _)
            if data ~= nil then
                local tmux_out = {}
                for token in string.gmatch(data, '([^' .. sep .. ']+)') do
                    table.insert(tmux_out, token)
                end
                if #tmux_out ~= 4 then
                    error('Did not collect sufficient information from tmux.' .. vim.inspect(tmux_out))
                    return
                end

                local pane_id = tmux_out[1]
                local active = tmux_out[2]
                local pane_cwd = tmux_out[3]
                local pane_cmd = tmux_out[4]
                if active ~= tmux_active then
                    table.insert(inactive_panes, pane_id)
                    table.insert(inactive_cwds, pane_cwd)
                    table.insert(inactive_commands, pane_cmd)
                end
            end
        end,
    }

    local res, ret = job:sync()
    if ret ~= 0 then
        error('Failed get_inactive_panes_and_cwds: ' .. ret .. vim.inspect(res))
    end
    return inactive_panes, inactive_cwds, inactive_commands
end

---@param pane_id string the ID of the pane to send the command to
---@param cmd string the command to run
function M.send_keys(pane_id, cmd)
    local job = Job:new {
        command = 'tmux',
        args = { 'send-keys', '-t', pane_id, cmd, 'Enter' },
        cwd = vim.loop.cwd(),
    }
    job:start()
end

function M.change_session_cwds(prev_path, path)
    local inactive_panes, cwds, commands = M.get_inactive_panes_and_cwds()
    for idx, pane_id in ipairs(inactive_panes) do
        if cwds[idx] == prev_path and is_shell_only(commands[idx]) then
            M.send_keys(pane_id, string.format('cd %s', path))
            -- Clear shell
            M.send_keys(pane_id, 'clear')
        end
    end
end

return M
