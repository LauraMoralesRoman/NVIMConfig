-- hermes_bridge/hermes.lua
-- Remote-first Hermes <-> Neovim bridge.
-- User command :Hermes <msg> writes a message file for Hermes to consume.
-- Hermes replies / acts by sending commands directly into the running nvim via
--   nvim --server <socket> --remote-send '...<CR>'
--
-- No polling on the nvim side.  All Hermes->Nvim traffic is push-based.

local M = {}

-- Send a message from nvim to Hermes.
-- Writes ~/.hermes/nvim-msg.json (consumed by Hermes on its next turn).
function M.send_message(text)
  if not text or #text == 0 then
    vim.notify('[Hermes] empty message', vim.log.levels.WARN)
    return false
  end

  local nvim_listen = vim.v.servername or ''
  local dir = vim.fn.expand('~/.hermes')
  vim.fn.mkdir(dir, 'p')

  local payload = vim.fn.json_encode {
    message     = text,
    timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    nvim_socket = nvim_listen,
    cwd         = vim.fn.getcwd(),
    buffer      = vim.api.nvim_buf_get_name(0),
  }

  vim.fn.writefile({ payload }, dir .. '/nvim-msg.json')
  vim.notify('[Hermes] message sent', vim.log.levels.INFO)
  return true
end

-- ---------------------------------------------------------------------------
-- API exposed for Hermes --remote-send injection.
-- Each function below can be triggered from a terminal via:
--   nvim --server <sock> --remote-send ':lua require("hermes_bridge.hermes").FUNC(args)<CR>'
-- ---------------------------------------------------------------------------

-- Show an on-screen notification.
function M.notify(text, level)
  level = level or vim.log.levels.INFO
  vim.notify('[Hermes] ' .. text, level)
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
-- NOTE: Hermes uses --remote-expr for direct eval when possible.
-- This helper is only needed if Hermes wants to run code that needs nvim
-- globals (vim.api, vim.fn, ...) which are available here but NOT in
-- "nvim --remote-expr" context.
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
-- Setup
-- ---------------------------------------------------------------------------

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
