-- hermes_bridge/hermes.lua
-- Minimal Hermes <-> Neovim bridge.
-- Single user command:  :Hermes <message>
-- Writes msg + nvim socket to ~/.hermes/nvim-msg.json for Hermes to consume.
-- Required: none. Optional: gitsigns.nvim notify used if available.

local M = {}

-- Send a message to Hermes agent.
-- Return: true if write succeeded.
function M.send_message(text)
  if not text or #text == 0 then
    vim.notify('[Hermes] empty message', vim.log.levels.WARN)
    return false
  end

  -- nvim listen address (socket path). nvim v0.10+ sets this when started with
  -- --listen or NVIM_LISTEN_ADDRESS. May be empty if nvim was started plain.
  local nvim_listen = vim.v.servername or ''

  local dir = vim.fn.expand '~/.hermes'
  vim.fn.mkdir(dir, 'p')

  local fname = dir .. '/nvim-msg.json'
  local payload = vim.fn.json_encode {
    message    = text,
    timestamp  = os.date '!%Y-%m-%dT%H:%M:%SZ',
    nvim_socket = nvim_listen,
    cwd        = vim.fn.getcwd(),
    buffer     = vim.api.nvim_buf_get_name(0),
  }

  vim.fn.writefile({ payload }, fname)

  -- Optionally flash a message via gitsigns notify if loaded
  local ok, gs = pcall(require, 'gitsigns')
  if ok and gs.notify then
    gs.notify('[Hermes] message sent', 'info')
  else
    vim.notify('[Hermes] message sent', vim.log.levels.INFO)
  end
  return true
end

-- Read any pending reply written by Hermes.
-- Return: string or nil.
function M.read_reply()
  local fname = vim.fn.expand '~/.hermes/hermes-reply.txt'
  if vim.fn.filereadable(fname) == 0 then
    return nil
  end
  local lines = vim.fn.readfile(fname)
  vim.fn.delete(fname)
  return table.concat(lines, '\n')
end

function M.setup()
  vim.api.nvim_create_user_command('Hermes', function(opts)
    if opts.args and #opts.args > 0 then
      M.send_message(opts.args)
    end
  end, {
    nargs = 1,
    desc  = 'Send an instruction to the Hermes agent',
  })
end

return M
