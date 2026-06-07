-- hermes-bridge/init.lua
-- Entry point for the Hermes-Neovim bridge.
--
-- Provides:
--   :Hermes <msg>     — sends a prompt/task to the orchestrator
--   :HermesCheckup    — opens the task status buffer
--   _G.hermes         — module for external (--remote-send) access

local M = {}

local HERMES_LISTENER = "/tmp/hermes-bridge-listener.sock"

function M.send_to_listener(payload)
  if type(payload) ~= "table" then
    return false
  end
  local ok, ch = pcall(vim.fn.sockconnect, "pipe", HERMES_LISTENER)
  if not ok or ch == 0 then
    return false
  end
  local sent = vim.fn.chansend(ch, vim.fn.json_encode(payload) .. "\n")
  vim.fn.chanclose(ch)
  return sent > 0
end

function M.get_context()
  local context = {
    current_file = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()),
    active_buffers = {},
    opened_buffers = {},
    cwd = vim.fn.getcwd(),
  }
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    table.insert(context.active_buffers, vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)))
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    table.insert(context.opened_buffers, vim.api.nvim_buf_get_name(buf))
  end
  return context
end

function M.get_visual_selection()
  local ok, result = pcall(vim.fn.getpos, "'<")
  if not ok then return end
  local _, ls = unpack(result)
  local _, le = unpack(vim.fn.getpos("'>"))
  if ls == 0 or le == 0 then return end
  return {
    start = ls,
    end_ = le,
    content = table.concat(vim.api.nvim_buf_get_lines(0, ls - 1, le, false), "\n"),
  }
end

function M.send_prompt(text, context, range)
  local payload = { type = "prompt", text = text, context = context or M.get_context() }
  if range then payload.range = range end
  if not M.send_to_listener(payload) then
    local ok, ch = pcall(vim.fn.sockconnect, "pipe", "/tmp/nvim-hermes-bridge.sock")
    if ok then vim.fn.chanclose(ch) end
    if ok and ch > 0 then
      vim.notify("[Hermes] Not in Neovim Mode: tell Hermes 'start neovim mode'", vim.log.levels.ERROR)
    else
      vim.notify("[Hermes] No bridge socket: run :HermesInit then tell Hermes 'start neovim mode'", vim.log.levels.ERROR)
    end
  else
    vim.notify("[Hermes] Sent: " .. text:sub(1, 60) .. (#text > 60 and "..." or ""), vim.log.levels.INFO)
  end
end

function M.cancel_task(task_id)
  M.send_to_listener({ type = "cancel", task_id = task_id })
end

function M.safe_notify(text, level)
  level = level or vim.log.levels.INFO
  local msg = tostring(text)
  local mode = vim.api.nvim_get_mode().mode
  if mode == "i" or mode == "R" or mode == "ic" then
    -- Queue for when user exits insert mode
    if not _G._hermes_notify_queue then
      _G._hermes_notify_queue = {}
      local group = vim.api.nvim_create_augroup("HermesNotifyFlush", { clear = true })
      vim.api.nvim_create_autocmd("InsertLeave", {
        group = group,
        callback = M.flush_notifications,
      })
    end
    table.insert(_G._hermes_notify_queue, { msg = msg, level = level })
  else
    vim.schedule(function()
      vim.notify("[Hermes] " .. msg, level)
    end)
  end
end

function M.flush_notifications()
  local mode = vim.api.nvim_get_mode().mode
  -- Only flush when actually leaving insert mode
  if mode == "i" or mode == "R" then return end
  if not _G._hermes_notify_queue or #_G._hermes_notify_queue == 0 then return end
  local queue = _G._hermes_notify_queue
  _G._hermes_notify_queue = {}
  vim.schedule(function()
    for _, item in ipairs(queue) do
      vim.notify("[Hermes] " .. item.msg, item.level)
    end
  end)
end

function M.notify(text, level)
  level = level or vim.log.levels.INFO
  vim.notify("[Hermes] " .. tostring(text), level)
end

function M.status(text)
  vim.cmd("echo '" .. text:gsub("'", "''") .. "'")
end

function M.set_task(desc, step, total)
  _G.hermes_task = { desc = desc, step = step, total = total }
  vim.cmd("redrawstatus")
end

function M.update_task(step, total)
  if not _G.hermes_task then return end
  _G.hermes_task.step = step
  _G.hermes_task.total = total
  vim.cmd("redrawstatus")
end

function M.clear_task()
  _G.hermes_task = nil
  vim.cmd("redrawstatus")
end

function _G.hermes_task_status()
  if not _G.hermes_task then return "" end
  return string.format(" [Hermes] %s | %d/%d ", _G.hermes_task.desc, _G.hermes_task.step, _G.hermes_task.total)
end

function M.setup()
  _G.hermes = M

  vim.api.nvim_create_user_command("Hermes", function(opts)
    local range = (opts.range and opts.range > 0) and M.get_visual_selection() or nil
    M.send_prompt(opts.args, nil, range)
  end, { nargs = 1, range = true, desc = "Send prompt to Hermes Agent" })

  vim.api.nvim_create_user_command("HermesCheckup", function()
    local ok, mod = pcall(require, "hermes-bridge.status-buffer")
    if ok and mod.open then mod.open()
    else vim.notify("[Hermes] Status buffer not available", vim.log.levels.ERROR) end
  end, { desc = "Open Hermes task status buffer" })

  vim.api.nvim_create_user_command("HermesInit", function()
    local sock = "/tmp/nvim-hermes-bridge.sock"
    local ok, r = pcall(vim.fn.serverstart, sock)
    if ok and r and r ~= "" then
      vim.notify("[Hermes] Bridge ready on " .. r, vim.log.levels.INFO)
    else
      -- Socket might be stale — try cleaning it and retry once
      os.remove(sock)
      ok, r = pcall(vim.fn.serverstart, sock)
      if ok and r and r ~= "" then
        vim.notify("[Hermes] Bridge ready on " .. r, vim.log.levels.INFO)
      else
        vim.notify("[Hermes] Could not start bridge server", vim.log.levels.ERROR)
      end
    end
  end, { desc = "Start Hermes bridge server on /tmp/nvim-hermes-bridge.sock" })
end

M.setup()
return M