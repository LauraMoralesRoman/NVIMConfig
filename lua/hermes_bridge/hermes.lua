-- hermes_bridge/hermes.lua
-- Queue-based Hermes <-> Neovim bridge.
--
-- Nvim side:
--   :Hermes <msg>   → writes ~/.hermes/nvim-msgs/<timestamp>.json
--   Each message is a separate queued file (no overwrite).
--
-- Hermes side (cron job):
--   Polls ~/.hermes/nvim-msgs/*.json every 10s while in "neovim mode".
--   Processes messages in chronological order, deletes after handling.
--   Replies via nvim --server <sock> --remote-send.
--
-- No polling on the nvim side. All Hermes->Nvim traffic is push-based.

local M = {}

-- Send a message from nvim to Hermes.
-- Writes ~/.hermes/nvim-msgs/<timestamp>.json.
function M.send_message(text)
  if not text or #text == 0 then
    vim.notify('[Hermes] empty message', vim.log.levels.WARN)
    return false
  end

  local nvim_listen = vim.v.servername or ''
  local dir = vim.fn.expand('~/.hermes/nvim-msgs')
  vim.fn.mkdir(dir, 'p')

  local ts = os.date('!%Y%m%d_%H%M%S')
  local fname = dir .. '/' .. ts .. '.json'

  -- If the same second, append counter to avoid collision
  if vim.fn.filereadable(fname) == 1 then
    local counter = 0
    repeat
      counter = counter + 1
      fname = dir .. '/' .. ts .. '_' .. counter .. '.json'
    until vim.fn.filereadable(fname) == 0
  end

  local payload = vim.fn.json_encode {
    message     = text,
    timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    nvim_socket = nvim_listen,
    cwd         = vim.fn.getcwd(),
    buffer      = vim.api.nvim_buf_get_name(0),
  }

  vim.fn.writefile({ payload }, fname)
  vim.notify('[Hermes] message queued', vim.log.levels.INFO)
  return true
end

-- ---------------------------------------------------------------------------
-- API exposed for Hermes --remote-send injection.
-- ---------------------------------------------------------------------------

-- Show an on-screen notification (popup, stays until dismissed).
function M.notify(text, level)
  level = level or vim.log.levels.INFO
  vim.notify('[Hermes] ' .. text, level)
end

-- Transient status update in the command line (auto-disappears).
function M.status(text)
  vim.api.nvim_echo({ { '[Hermes] ' .. text, 'Comment' } }, false, {})
end

-- Open a file in the current window.
function M.edit_file(path)
  if not path or #path == 0 then return end
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
end

-- Execute any ex command (use with care).
function M.command(cmd)
  if not cmd or #cmd == 0 then return end
  vim.cmd(cmd)
end

-- Evaluate a Lua expression string and return the result.
function M.eval(expr)
  if not expr or #expr == 0 then return nil end
  local fn, err = load('return ' .. expr, 'hermes-eval')
  if not fn then
    M.notify('eval error: ' .. tostring(err), vim.log.levels.ERROR)
    return nil
  end
  return fn()
end

-- ---------------------------------------------------------------------------
-- Remote state inspection (queried by Hermes via --remote-expr).
-- ---------------------------------------------------------------------------

-- Return a JSON string describing the full nvim state.
function M.state_json()
  local state = {
    cwd         = vim.fn.getcwd(),
    mode        = vim.api.nvim_get_mode().mode,
    buffer      = {
      name   = vim.api.nvim_buf_get_name(0),
      number = vim.api.nvim_get_current_buf(),
      line   = vim.api.nvim_win_get_cursor(0)[1],
      col    = vim.api.nvim_win_get_cursor(0)[2],
    },
    buffers     = {},
    tabs        = {},
  }

  -- All listed buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name and #name > 0 then
        table.insert(state.buffers, name)
      end
    end
  end

  -- All tabs and their window buffers
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local tab_info = { windows = {} }
    vim.api.nvim_set_current_tabpage(tab)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      local buf = vim.api.nvim_win_get_buf(win)
      local name = vim.api.nvim_buf_get_name(buf)
      table.insert(tab_info.windows, name)
    end
    table.insert(state.tabs, tab_info)
  end

  -- Restore current tab
  vim.api.nvim_set_current_tabpage(vim.api.nvim_get_current_tabpage())

  return vim.fn.json_encode(state)
end

-- Shorthand for quick buffer list (JSON array).
function M.buffers_json()
  local names = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name and #name > 0 then
        table.insert(names, name)
      end
    end
  end
  return vim.fn.json_encode(names)
end

-- Shorthand for current file + cursor (JSON object).
function M.cursor_json()
  return vim.fn.json_encode({
    file = vim.api.nvim_buf_get_name(0),
    line = vim.api.nvim_win_get_cursor(0)[1],
    col  = vim.api.nvim_win_get_cursor(0)[2],
    mode = vim.api.nvim_get_mode().mode,
  })
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

function M.setup()
  vim.api.nvim_create_user_command('Hermes', function(opts)
    if opts.args and #opts.args > 0 then
      M.send_message(opts.args)
    end
  end, {
    nargs = 1,
    desc  = 'Send an instruction to the Hermes agent (queued)',
  })

  vim.api.nvim_create_user_command('HermesInit', function()
    -- Open a new tab with a terminal running the Hermes CLI
    vim.cmd('tabnew')
    vim.cmd('terminal hermes')

    -- Also queue the activation message so the background bridge wakes up
    M.send_message('enter neovim mode')

    vim.notify('[Hermes] Bridge tab opened — neovim mode activated', vim.log.levels.INFO)
  end, {
    nargs = 0,
    desc  = 'Open a Hermes terminal tab and activate neovim mode',
  })
end

return M
