-- hermes-bridge/status-buffer.lua
-- :HermesCheckup — opens a floating buffer showing task status.
--
-- The buffer is organised into three sections:
--   ACTIVE TASKS   — running and finishing tasks with collapsible logs
--   QUEUED         — tasks waiting for a slot
--   TASK HISTORY   — completed and cancelled tasks
--
-- Keymaps in the buffer:
--   q / <Esc>  — close
--   dd        — on history: delete from DB (with confirm)
--             — on active/queued: cancel the task
--   <CR>      — on history: open a temp buffer with full task log

local M = {}

local DB_SCRIPT = vim.fn.expand("~/.hermes/scripts/bridge-db.py")

--- Query the SQLite DB for task data.
--- Returns a list of task rows, or nil on error.
---@param status_filter string|nil  Optional status to filter by
---@return table|nil
function M.query_tasks(status_filter)
  local cmd = { "python3", DB_SCRIPT, "list" }
  if status_filter then
    table.insert(cmd, status_filter)
  end
  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  local ok, data = pcall(vim.fn.json_decode, result)
  if not ok then
    return nil
  end
  return data
end

--- Query log messages for a specific task.
---@param task_id string
---@return table|nil
function M.query_task_log(task_id)
  local cmd = { "python3", DB_SCRIPT, "log", task_id }
  local result = vim.fn.system(cmd)
  return vim.split(result, "\n", { trimempty = true })
end

--- Build the status buffer content.
---@param buf number  Buffer handle to populate
function M.populate_buffer(buf)
  local lines = {}

  -- Fetch all tasks from DB
  local tasks = M.query_tasks()
  if not tasks then
    lines = {
      "═══════════════════════════════════════════",
      "",
      "  SQLite database not available.",
      "  (Start Neovim Mode first)",
    }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    return
  end

  table.insert(lines, "═══════════════════════════════════════════")
  table.insert(lines, "")

  -- ACTIVE TASKS (running + finishing)
  table.insert(lines, "> ACTIVE TASKS")
  table.insert(lines, "  ════════════")
  table.insert(lines, "")
  local active_count = 0
  for _, t in ipairs(tasks) do
    if t.status == "running" or t.status == "finishing" then
      active_count = active_count + 1
      table.insert(lines, string.format("\t> TASK [%s]\t\t\t[%s]", t.description, t.status))
      -- Append log messages
      local logs = M.query_task_log(t.id)
      if logs and #logs > 0 then
        for _, log_line in ipairs(logs) do
          table.insert(lines, string.format("\t  %s", log_line))
        end
      end
      table.insert(lines, "")
    end
  end
  if active_count == 0 then
    table.insert(lines, "\t(No active tasks)")
    table.insert(lines, "")
  end

  -- QUEUED
  table.insert(lines, "> QUEUED")
  table.insert(lines, "  ══════")
  table.insert(lines, "")
  local queued_count = 0
  for _, t in ipairs(tasks) do
    if t.status == "queued" then
      queued_count = queued_count + 1
      table.insert(lines, string.format("\t> TASK [%s]\t\t\t[queued]", t.description))
    end
  end
  if queued_count == 0 then
    table.insert(lines, "\t(No queued tasks)")
  end
  table.insert(lines, "")

  -- TASK HISTORY
  table.insert(lines, "> TASK HISTORY")
  table.insert(lines, "  ════════════")
  table.insert(lines, "")
  local history_count = 0
  for _, t in ipairs(tasks) do
    if t.status == "completed" or t.status == "cancelled" then
      history_count = history_count + 1
      local created = t.created_at or ""
      table.insert(lines, string.format("\t[%s] %s\t\t[%s]", created, t.description, t.status))
    end
  end
  if history_count == 0 then
    table.insert(lines, "\t(No completed or cancelled tasks)")
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

--- Open the Hermes status buffer in a floating window.
function M.open()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_name(buf, "HermesStatus")

  -- Calculate window dimensions
  local ui = vim.api.nvim_list_uis()[1]
  local width = math.min(80, ui and ui.width - 4 or 80)
  local height = math.min(24, ui and ui.height - 4 or 24)
  local row = math.max(1, (ui and ui.height or 24) - height - 2)
  local col = math.floor(((ui and ui.width or 80) - width) / 2)

  -- Open the floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "single",
    title = " Hermes Tasks ",
    title_pos = "center",
  })

  -- Keymaps
  local opts = { buffer = buf, nowait = true }
  vim.keymap.set("n", "q", "<cmd>close<CR>", opts)
  vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", opts)
  vim.keymap.set("n", "r", function()
    M.populate_buffer(buf)
    vim.notify("[Hermes] Status refreshed", vim.log.levels.INFO)
  end, opts)
  vim.keymap.set("n", "dd", function()
    -- Get the line under cursor
    local line = vim.api.nvim_get_current_line()
    local task_id = line:match("%[%w+%-%w+%-%w+%-%w+%-%w+%]")
    if task_id then
      local choice = vim.fn.confirm(
        "Cancel task " .. task_id .. "?",
        "&Yes\n&No",
        2
      )
      if choice == 1 then
        if _G.hermes and _G.hermes.cancel_task then
          _G.hermes.cancel_task(task_id)
          vim.notify("[Hermes] Cancelled " .. task_id, vim.log.levels.WARN)
          M.populate_buffer(buf)
        end
      end
    end
  end, opts)

  -- Populate the buffer
  M.populate_buffer(buf)

  -- Set buffer as readonly for user
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

return M