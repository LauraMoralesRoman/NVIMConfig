-- hermes-bridge/init.lua
-- Entry point for the Hermes-Neovim bridge.
--
-- Provides:
--   :Hermes <msg>     — sends a prompt/task to the orchestrator
--   :HermesCheckup    — opens the task status buffer
--   _G.hermes         — module for external (--remote-send) access

local M = {}

local HERMES_LISTENER = "/tmp/hermes-bridge-listener.sock"
local NVIM_BRIDGE_SOCKET = "/tmp/nvim-hermes-bridge.sock"

----------------------------------------------------------------------
-- Socket communication with the Hermes listener
----------------------------------------------------------------------

--- Send a JSON payload to the Hermes listener socket.
--- This is a fire-and-forget call. If the listener is not running,
--- the connect silently fails (returns false, no crash).
---@param payload table  Lua table to encode as JSON
---@return boolean true if sent, false if listener unavailable
function M.send_to_listener(payload)
  if type(payload) ~= "table" then
    return false
  end
  local ok_connect, ch = pcall(vim.fn.sockconnect, "pipe", HERMES_LISTENER)
  if not ok_connect or ch == 0 then
    return false
  end
  local sent = vim.fn.chansend(ch, vim.fn.json_encode(payload) .. "\n")
  vim.fn.chanclose(ch, "stdin")
  return sent > 0
end

----------------------------------------------------------------------
-- Context snapshot
----------------------------------------------------------------------

--- Get a snapshot of the current editor context.
---@return table { current_file, active_buffers, opened_buffers, cwd }
function M.get_context()
  local cur_buf = vim.api.nvim_get_current_buf()
  local context = {
    current_file = vim.api.nvim_buf_get_name(cur_buf),
    active_buffers = {},
    opened_buffers = {},
    cwd = vim.fn.getcwd(),
  }
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    table.insert(context.active_buffers, vim.api.nvim_buf_get_name(buf))
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    table.insert(context.opened_buffers, vim.api.nvim_buf_get_name(buf))
  end
  return context
end

--- Get the visual selection range and content.
---@return table|nil { start, end_, content } or nil if no selection active
function M.get_visual_selection()
  local ok, result = pcall(vim.fn.getpos, "'<")
  if not ok then return nil end
  local _, ls, cs = unpack(result)
  local _, le, ce = unpack(vim.fn.getpos("'>"))
  if ls == 0 or le == 0 then return nil end
  local lines = vim.api.nvim_buf_get_lines(0, ls - 1, le, false)
  return {
    start = ls,
    end_ = le,
    content = table.concat(lines, "\n"),
  }
end

----------------------------------------------------------------------
-- :Hermes command — sends prompts to the orchestrator
----------------------------------------------------------------------

function M.send_prompt(text, context, range)
  local payload = {
    type = "prompt",
    text = text,
    context = context or M.get_context(),
  }
  if range then
    payload.range = range
  end
  local sent = M.send_to_listener(payload)
  if not sent then
    vim.notify("[Hermes] Bridge listener not running (start Neovim Mode first)", vim.log.levels.WARN)
  end
end

function M.cancel_task(task_id)
  M.send_to_listener({
    type = "cancel",
    task_id = task_id,
  })
end

----------------------------------------------------------------------
-- Notification helpers (for external --remote-send calls)
----------------------------------------------------------------------

function M.safe_notify(text, level)
  level = level or vim.log.levels.INFO
  local msg = tostring(text)
  vim.schedule(function()
    vim.notify("[Hermes] " .. msg, level)
  end)
end

function M.notify(text, level)
  level = level or vim.log.levels.INFO
  vim.notify("[Hermes] " .. tostring(text), level)
end

function M.status(text)
  vim.cmd("echo '" .. text:gsub("'", "''") .. "'")
end

----------------------------------------------------------------------
-- Task progress in statusline
----------------------------------------------------------------------

function M.set_task(desc, step, total)
  _G.hermes_task = { desc = desc, step = step, total = total }
  vim.cmd("redrawstatus")
end

function M.update_task(step, total)
  if _G.hermes_task then
    _G.hermes_task.step = step
    _G.hermes_task.total = total
    vim.cmd("redrawstatus")
  end
end

function M.clear_task()
  _G.hermes_task = nil
  vim.cmd("redrawstatus")
end

----------------------------------------------------------------------
-- Statusline helper (called from options.lua statusline)
----------------------------------------------------------------------

function _G.hermes_task_status()
  if not _G.hermes_task then return "" end
  local t = _G.hermes_task
  return string.format(" [Hermes] %s | %d/%d ", t.desc, t.step, t.total)
end

----------------------------------------------------------------------
-- Setup — register user commands
----------------------------------------------------------------------

function M.setup()
  _G.hermes = M

  -- :Hermes <msg> — send prompt to orchestrator
  vim.api.nvim_create_user_command("Hermes", function(opts)
    local range = nil
    if opts.range and opts.range > 0 then
      range = M.get_visual_selection()
    end
    M.send_prompt(opts.args, nil, range)
  end, { nargs = 1, range = true, desc = "Send prompt to Hermes Agent" })

  -- :HermesCheckup — open task status buffer
  vim.api.nvim_create_user_command("HermesCheckup", function()
    local ok, status_buf = pcall(require, "hermes-bridge.status-buffer")
    if ok and status_buf.open then
      status_buf.open()
    else
      vim.notify("[Hermes] Status buffer module not available", vim.log.levels.ERROR)
    end
  end, { desc = "Open Hermes task status buffer" })
end

-- Auto-setup
M.setup()

return M