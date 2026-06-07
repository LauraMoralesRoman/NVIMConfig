local M = {}
local DB = vim.fn.expand("~/.hermes/scripts/bridge-db.py")

function M.query_tasks(filter)
  local cmd = { "python3", DB, "list" }
  if filter then table.insert(cmd, filter) end
  local r = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then return nil end
  local ok, data = pcall(vim.fn.json_decode, r)
  return ok and data or nil
end

function M.query_task_log(task_id)
  local r = vim.fn.system({ "python3", DB, "logs", task_id })
  local ok, data = pcall(vim.fn.json_decode, r)
  if ok then return data end
  return {}
end

function M.populate_buffer(buf)
  local tasks = M.query_tasks()
  if not tasks then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "═══════════════════════════════════════════", "",
      "  SQLite database not available.", "  (Start Neovim Mode first)",
    })
    return
  end

  local lines = { "═══════════════════════════════════════════", "" }

  table.insert(lines, "> ACTIVE TASKS")
  table.insert(lines, "  ════════════")
  table.insert(lines, "")
  local n = 0
  for _, t in ipairs(tasks) do
    if t.status == "running" or t.status == "finishing" then
      n = n + 1
      table.insert(lines, string.format("\t> TASK [%s]\t\t\t[%s]", t.description, t.status))
      for _, log in ipairs(M.query_task_log(t.id)) do
        table.insert(lines, string.format("\t  [%s] %s", log.timestamp, log.message))
      end
      table.insert(lines, "")
    end
  end
  if n == 0 then table.insert(lines, "\t(No active tasks)"); table.insert(lines, "") end

  table.insert(lines, "> QUEUED")
  table.insert(lines, "  ══════")
  table.insert(lines, "")
  n = 0
  for _, t in ipairs(tasks) do
    if t.status == "queued" then
      n = n + 1
      table.insert(lines, string.format("\t> TASK [%s]\t\t\t[queued]", t.description))
    end
  end
  if n == 0 then table.insert(lines, "\t(No queued tasks)") end
  table.insert(lines, "")

  table.insert(lines, "> TASK HISTORY")
  table.insert(lines, "  ════════════")
  table.insert(lines, "")
  n = 0
  for _, t in ipairs(tasks) do
    if t.status == "completed" or t.status == "cancelled" then
      n = n + 1
      table.insert(lines, string.format("\t[%s] %s\t\t[%s]", t.created_at or "", t.description, t.status))
    end
  end
  if n == 0 then table.insert(lines, "\t(No completed or cancelled tasks)") end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

function M.open()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_buf_set_name(buf, "HermesStatus")

  local ui = vim.api.nvim_list_uis()[1]
  local w = math.min(80, ui and ui.width - 4 or 80)
  local h = math.min(24, ui and ui.height - 4 or 24)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = w, height = h,
    row = math.max(1, (ui and ui.height or 24) - h - 2),
    col = math.floor(((ui and ui.width or 80) - w) / 2),
    style = "minimal", border = "single",
    title = " Hermes Tasks ", title_pos = "center",
  })

  local opts = { buffer = buf, nowait = true }
  vim.keymap.set("n", "q",     "<cmd>close<CR>", opts)
  vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", opts)
  vim.keymap.set("n", "r", function() M.populate_buffer(buf)
    vim.notify("[Hermes] Refreshed", vim.log.levels.INFO) end, opts)
  vim.keymap.set("n", "dd", function()
    local id = vim.api.nvim_get_current_line():match("[%w-]+")
    if id and vim.fn.confirm("Cancel " .. id .. "?", "&Yes\n&No", 2) == 1 then
      if _G.hermes and _G.hermes.cancel_task then
        _G.hermes.cancel_task(id)
        M.populate_buffer(buf)
      end
    end
  end, opts)

  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  M.populate_buffer(buf)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

return M