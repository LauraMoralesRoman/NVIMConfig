local M = {}
local DB = vim.fn.expand("~/.hermes/scripts/bridge-db.py")

-- Buffer-local line number → task_id mapping
local buf_task_map = setmetatable({}, { __mode = "v" })

-- Status → highlight group mapping
local status_hl = {
  running   = "HermesStatusRunning",
  finishing = "HermesStatusFinishing",
  queued    = "HermesStatusQueued",
  completed = "HermesStatusCompleted",
  cancelled = "HermesStatusCancelled",
}

-- Define highlight groups (blue=#7aa2f7, cyan=#7dcfff, gold=#e0af68, green=#9ece6a, red=#f7768e)
local hl_defs = {
  HermesHeader       = { fg = "#bb9af7", bold = true },
  HermesSection      = { fg = "#7aa2f7", bold = true },
  HermesSubHeader    = { fg = "#565f89" },
  HermesStatusRunning   = { fg = "#7aa2f7", bold = true },
  HermesStatusFinishing = { fg = "#7dcfff", bold = true },
  HermesStatusQueued    = { fg = "#e0af68", bold = true },
  HermesStatusCompleted = { fg = "#9ece6a" },
  HermesStatusCancelled = { fg = "#f7768e" },
  HermesTaskDesc     = { fg = "#c0caf5" },
  HermesTimestamp    = { fg = "#565f89" },
  HermesLogMessage   = { fg = "#9aa5ce" },
  HermesEmpty        = { fg = "#565f89", italic = true },
  HermesSeparator    = { fg = "#3b4261" },
}

for name, def in pairs(hl_defs) do
  vim.api.nvim_set_hl(0, name, def)
end

local sep = "\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128\226\148\128"

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

-- Truncate UUID to first 8 chars for display
local function short_id(id)
  return id:sub(1, 8)
end

-- Pad right to align columns
local function pad_right(s, len)
  if #s >= len then return s end
  return s .. string.rep(" ", len - #s)
end

function M.populate_buffer(buf)
  buf_task_map[buf] = {}

  local tasks = M.query_tasks()
  if not tasks then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "",
      "  \239\129\151  SQLite database not available.",
      "  Start Neovim Mode first: tell Hermes 'start neovim mode'",
    })
    return
  end

  -- Categorise
  local active = {}
  local queued = {}
  local history = {}
  for _, t in ipairs(tasks) do
    if t.status == "running" or t.status == "finishing" then
      table.insert(active, t)
    elseif t.status == "queued" then
      table.insert(queued, t)
    elseif t.status == "completed" or t.status == "cancelled" then
      table.insert(history, t)
    end
  end

  local lines = {}
  local function L(s) table.insert(lines, s) end

  -- ── HEADER ──
  L("")
  L("  \226\157\161  Hermes Tasks")
  L("  " .. sep)
  L("")

  -- ── ACTIVE TASKS ──
  L("  \239\131\136  ACTIVE  (" .. #active .. ")")
  L("")
  if #active == 0 then
    L("    (no active tasks)")
    L("")
  else
    for _, t in ipairs(active) do
      local sid = short_id(t.id)
      local status = t.status
      local hl = status_hl[status] or "Normal"

      -- Task header line: id  description  [status]
      local header = string.format("    %s \226\148\128 %s", sid, t.description)
      local line_num = #lines + 1
      L(header)

      -- Now use extmarks for highlighting on this line
      buf_task_map[buf][line_num] = {
        id = t.id,
        is_header = true,
        collapsed = false,
        description = t.description,
        status = status,
      }

      -- Log entries (indented, dimmed)
      local logs = M.query_task_log(t.id)
      for _, log in ipairs(logs) do
        local ts = log.timestamp:sub(12, 19) or log.timestamp  -- HH:MM:SS
        L(string.format("      \226\148\130  %s  %s", ts, log.message))
      end
      L("")
    end
  end

  -- ── QUEUED ──
  L("  \239\131\173  QUEUED  (" .. #queued .. ")")
  L("")
  if #queued == 0 then
    L("    (empty)")
    L("")
  else
    for _, t in ipairs(queued) do
      local sid = short_id(t.id)
      local line_num = #lines + 1
      L(string.format("    %s \226\148\128 %s", sid, t.description))
      buf_task_map[buf][line_num] = {
        id = t.id,
        is_queued = true,
      }
    end
    L("")
  end

  -- ── HISTORY ──
  L("  \239\131\139  HISTORY  (" .. #history .. ")")
  L("")
  if #history == 0 then
    L("    (no completed tasks yet)")
  else
    for _, t in ipairs(history) do
      local sid = short_id(t.id)
      local ts = t.created_at:sub(1, 10) or ""   -- YYYY-MM-DD
      local line_num = #lines + 1
      L(string.format("    %s  %s  \226\148\128  %s", ts, sid, t.description))
      buf_task_map[buf][line_num] = {
        id = t.id,
        is_history = true,
        status = t.status,
      }
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Apply extmarks for syntax highlighting
  local ns = vim.api.nvim_create_namespace("HermesStatus")
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  for lnum, info in pairs(buf_task_map[buf] or {}) do
    local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
    if not line then
      -- skip
    elseif info.is_header then
      -- Highlight status tag at end of line (the description text)
      local hl_name = status_hl[info.status] or "Normal"
      -- Highlight the short ID
      vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 4, {
        end_col = 4 + 8,
        hl_group = hl_name,
      })
      -- Highlight the description
      vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 4 + 9 + 3, {
        end_col = #line,
        hl_group = "HermesTaskDesc",
      })
    elseif info.is_queued then
      vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 4, {
        end_col = 4 + 8,
        hl_group = "HermesStatusQueued",
      })
      vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 4 + 9 + 3, {
        end_col = #line,
        hl_group = "HermesTaskDesc",
      })
    elseif info.is_history then
      -- Highlight timestamp dim, ID colored by final status
      local hl_name = status_hl[info.status] or "Normal"
      vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 4, {
        end_col = 4 + 10,
        hl_group = "HermesTimestamp",
      })
      vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 4 + 12, {
        end_col = 4 + 12 + 8,
        hl_group = hl_name,
      })
      vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 4 + 12 + 9 + 3, {
        end_col = #line,
        hl_group = "HermesTaskDesc",
      })
    end
  end

  -- Section headers + body highlights
  for lnum_minus1 = 0, #lines - 1 do
    local line = lines[lnum_minus1 + 1]
    if line:match("^\239\131\136  ACTIVE") then
      vim.api.nvim_buf_set_extmark(buf, ns, lnum_minus1, 0, { end_col = #line, hl_group = "HermesSection" })
    elseif line:match("^\239\131\173  QUEUED") then
      vim.api.nvim_buf_set_extmark(buf, ns, lnum_minus1, 0, { end_col = #line, hl_group = "HermesSection" })
    elseif line:match("^\239\131\139  HISTORY") then
      vim.api.nvim_buf_set_extmark(buf, ns, lnum_minus1, 0, { end_col = #line, hl_group = "HermesSection" })
    elseif line:match("^  \226\157\161  Hermes Tasks") then
      vim.api.nvim_buf_set_extmark(buf, ns, lnum_minus1, 0, { end_col = #line, hl_group = "HermesHeader" })
    elseif line:match("^\226\148\128\226\148\128\226\148\128\226\148\128") and #line > 40 then
      vim.api.nvim_buf_set_extmark(buf, ns, lnum_minus1, 0, { end_col = #line, hl_group = "HermesSeparator" })
    elseif line:match("^    %(no") or line:match("^    %(empty") then
      vim.api.nvim_buf_set_extmark(buf, ns, lnum_minus1, 0, { end_col = #line, hl_group = "HermesEmpty" })
    elseif line:match("^      \226\148\130") then
      -- Log entries
      vim.api.nvim_buf_set_extmark(buf, ns, lnum_minus1, 2, { end_col = 22, hl_group = "HermesTimestamp" })
      vim.api.nvim_buf_set_extmark(buf, ns, lnum_minus1, 22, { end_col = #line, hl_group = "HermesLogMessage" })
    end
  end
end

function M.open()
  -- Open in a new tab
  vim.cmd("tabnew")

  local buf = vim.api.nvim_get_current_buf()
  buf_task_map[buf] = {}

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_buf_set_name(buf, "HermesStatus")
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_set_option_value("tabstop", 2, { buf = buf })

  -- Keymaps
  local opts = { buffer = buf, nowait = true }
  vim.keymap.set("n", "q", "<cmd>tabclose<CR>", opts)
  vim.keymap.set("n", "<Esc>", "<cmd>tabclose<CR>", opts)

  vim.keymap.set("n", "r", function()
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    M.populate_buffer(buf)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    vim.notify("[Hermes] Refreshed", vim.log.levels.INFO)
  end, opts)

  vim.keymap.set("n", "<CR>", function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local info = buf_task_map[buf] and buf_task_map[buf][lnum]
    if not info or not info.is_history then return end

    -- Open full task log in a temp buffer (vertical split)
    local logs = M.query_task_log(info.id)
    vim.cmd("vsplit")
    local log_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = log_buf })
    vim.api.nvim_buf_set_name(log_buf, "HermesLog-" .. info.id:sub(1, 8))

    local log_lines = { "Task: " .. info.id, string.rep("\226\148\128", 60), "" }
    for _, entry in ipairs(logs) do
      table.insert(log_lines, string.format("[%s] %s", entry.timestamp, entry.message))
    end
    if #logs == 0 then table.insert(log_lines, "(no log entries)") end

    vim.api.nvim_buf_set_lines(log_buf, 0, -1, false, log_lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = log_buf })
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = log_buf, nowait = true })
  end, opts)

  vim.keymap.set("n", "dd", function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local info = buf_task_map[buf] and buf_task_map[buf][lnum]
    if not info then
      vim.notify("[Hermes] No task on this line", vim.log.levels.WARN)
      return
    end

    if info.is_history then
      -- Delete from history
      local confirm = vim.fn.confirm("Delete task " .. info.id:sub(1, 8) .. " from history?", "&Yes\n&No", 2)
      if confirm == 1 then
        vim.fn.system({ "python3", DB, "delete", info.id })
        M.populate_buffer(buf)
        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
        vim.notify("[Hermes] Deleted " .. info.id:sub(1, 8), vim.log.levels.INFO)
      end
    else
      -- Cancel active/queued task
      local confirm = vim.fn.confirm("Cancel task " .. info.id:sub(1, 8) .. "?", "&Yes\n&No", 2)
      if confirm == 1 then
        if _G.hermes and _G.hermes.cancel_task then
          _G.hermes.cancel_task(info.id)
        end
        M.populate_buffer(buf)
        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
        vim.notify("[Hermes] Cancelling " .. info.id:sub(1, 8), vim.log.levels.WARN)
      end
    end
  end, opts)

  M.populate_buffer(buf)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

return M