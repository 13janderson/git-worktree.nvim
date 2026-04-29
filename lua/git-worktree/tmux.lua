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
        print(string.format('[git-worktree] SHELL not set, treating pane as non-shell (cmd: %s)', command))
        return false
    end
    local shell_name = default_shell:match('([^/]+)$')
    local cmd_name = command:match('([^/]+)$') or command
    local is_shell = cmd_name == shell_name
    print(string.format('[git-worktree] Shell check: cmd=%s, shell=%s, is_shell=%s', cmd_name, shell_name, tostring(is_shell)))
    return is_shell
end

---Get the current pane ID from environment variable
---@return string|nil
local function get_current_pane_id()
    local tmux_pane = vim.env.TMUX_PANE
    return tmux_pane
end

---@return table, table, table
--- table of the tmux pane IDs (excluding current pane)
--- table of cwd's of all panes... in the same order as the first table.
--- table of commands of all panes... in the same order as the first table.
function M.get_session_panes_and_cwds()
    local current_pane_id = get_current_pane_id()
    local panes = {}
    local pane_cwds = {}
    local pane_commands = {}

    print('[git-worktree] Fetching panes from current tmux session...')
    print(string.format('[git-worktree] Current pane ID (will be skipped): %s', tostring(current_pane_id)))
    local sep = ','
    local job = Job:new {
        command = 'tmux',
        args = {
            'list-panes',
            '-s',  -- Limit to current session only
            '-F',
            string.format('#{pane_id},#{pane_current_path},#{pane_current_command}'),
        },
        cwd = vim.loop.cwd(),
        on_stdout = function(_, data, _)
            if data ~= nil then
                local tmux_out = {}
                for token in string.gmatch(data, '([^' .. sep .. ']+)') do
                    table.insert(tmux_out, token)
                end
                if #tmux_out ~= 3 then
                    error('Did not collect sufficient information from tmux.' .. vim.inspect(tmux_out))
                    return
                end

                local pane_id = tmux_out[1]
                local pane_cwd = tmux_out[2]
                local pane_cmd = tmux_out[3]

                -- Skip the current pane (where Neovim is running)
                if pane_id == current_pane_id then
                    print(string.format('[git-worktree] Skipping current pane: id=%s, cwd=%s, cmd=%s', pane_id, pane_cwd, pane_cmd))
                else
                    print(string.format('[git-worktree] Found pane: id=%s, cwd=%s, cmd=%s', pane_id, pane_cwd, pane_cmd))
                    table.insert(panes, pane_id)
                    table.insert(pane_cwds, pane_cwd)
                    table.insert(pane_commands, pane_cmd)
                end
            end
        end,
    }

    local res, ret = job:sync()
    if ret ~= 0 then
        error('Failed get_session_panes_and_cwds: ' .. ret .. vim.inspect(res))
    end
    print(string.format('[git-worktree] Total panes found (excluding current): %d', #panes))
    return panes, pane_cwds, pane_commands
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
    print(string.format('[git-worktree] Changing session CWDs from %s to %s', prev_path, path))
    local panes, cwds, commands = M.get_session_panes_and_cwds()
    for idx, pane_id in ipairs(panes) do
        local pane_cwd = cwds[idx]
        local pane_cmd = commands[idx]
        print(string.format('[git-worktree] Checking pane %s: cwd=%s (expected %s), cmd=%s', pane_id, pane_cwd, prev_path, pane_cmd))
        if pane_cwd ~= prev_path then
            print(string.format('[git-worktree] SKIPPING pane %s: CWD mismatch (pane: %s, expected: %s)', pane_id, pane_cwd, prev_path))
        elseif not is_shell_only(pane_cmd) then
            print(string.format('[git-worktree] SKIPPING pane %s: not running shell (running: %s)', pane_id, pane_cmd))
        else
            print(string.format('[git-worktree] CHANGING pane %s: cd %s', pane_id, path))
            M.send_keys(pane_id, string.format('cd %s', path))
            -- Clear shell
            M.send_keys(pane_id, 'clear')
        end
    end
end

return M
