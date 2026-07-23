local icons = {
  [vim.log.levels.INFO]  = " ",
  [vim.log.levels.WARN]  = " ",
  [vim.log.levels.ERROR] = " ",
}

-- Define highlight groups for each notification level
local hl_colors = {
  [vim.log.levels.INFO]  = { fg = "#7aa2f7", bg = "#1a1b26" },
  [vim.log.levels.WARN]  = { fg = "#e0af68", bg = "#1a1b26" },
  [vim.log.levels.ERROR] = { fg = "#f7768e", bg = "#1a1b26" },
}

local hl_names = {
  [vim.log.levels.INFO]  = "HermesNotifyInfo",
  [vim.log.levels.WARN]  = "HermesNotifyWarn",
  [vim.log.levels.ERROR] = "HermesNotifyError",
}

for level, colors in pairs(hl_colors) do
  local name = hl_names[level]
  vim.api.nvim_set_hl(0, name, { fg = colors.fg, bg = colors.bg })
end

if not _G._original_vim_notify then
  _G._original_vim_notify = vim.notify
end

-- Track active notifications so they stack vertically from the bottom-right.
-- Each entry: { win = win_id, buf = buf_id, width = w }
local active = {}

-- Gap (in screen rows) between stacked notifications.
local GAP = 1

-- Recompute row positions for all active notifications, stacking from the
-- bottom of the editor upwards.
local function reflow()
  local ui = vim.api.nvim_list_uis()[1]
  if not ui then return end
  local row = ui.height - 3 -- bottom anchor (above status line)
  for i = #active, 1, -1 do
    local item = active[i]
    if vim.api.nvim_win_is_valid(item.win) then
      vim.api.nvim_win_set_config(item.win, {
        relative = "editor",
        row = row,
        col = ui.width - item.width - 1,
      })
      row = row - 1 - GAP -- 1 line of content + gap
    end
  end
end

vim.notify = function(msg, log_level, _opts)
  log_level = log_level or vim.log.levels.INFO
  local icon = icons[log_level] or " "
  local hl_name = hl_names[log_level] or "HermesNotifyInfo"

  vim.schedule(function()
    local ui = vim.api.nvim_list_uis()[1]
    if not ui then
      if _G._original_vim_notify then _G._original_vim_notify(msg, log_level)
      else print(msg) end
      return
    end

    local display = icon .. msg
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { display })

    local width = math.min(#display + 2, ui.width - 2)
    -- Place this notification above the current stack.
    local row = ui.height - 3 - (#active * (1 + GAP))
    local win = vim.api.nvim_open_win(buf, false, {
      relative = "editor",
      width = width,
      height = 1,
      row = row,
      col = ui.width - width - 1,
      style = "minimal",
      border = "none",
      zindex = 50,
      noautocmd = true,
    })

    -- Apply the coloured highlight
    vim.api.nvim_set_option_value("winhighlight", "Normal:" .. hl_name .. ",NormalNC:" .. hl_name, { win = win })

    local entry = { win = win, buf = buf, width = width }
    table.insert(active, entry)

    local timeout = log_level == vim.log.levels.ERROR and 5000 or 3000
    vim.defer_fn(function()
      -- Remove from the active list.
      for i, item in ipairs(active) do
        if item.win == win then
          table.remove(active, i)
          break
        end
      end
      pcall(vim.api.nvim_win_close, win, true)
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
      -- Shift remaining notifications down to fill the gap.
      reflow()
    end, timeout)
  end)

  return msg
end