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

vim.notify = function(msg, log_level, _opts)
  log_level = log_level or vim.log.levels.INFO
  local icon = icons[log_level] or " "
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
    local win = vim.api.nvim_open_win(buf, false, {
      relative = "editor",
      width = width,
      height = 1,
      row = ui.height - 3,
      col = ui.width - width - 1,
      style = "minimal",
      border = "none",
      zindex = 50,
      noautocmd = true,
    })

    -- Apply the coloured highlight
    vim.api.nvim_set_option_value("winhighlight", "Normal:" .. hl_name .. ",NormalNC:" .. hl_name, { win = win })

    local timeout = log_level == vim.log.levels.ERROR and 5000 or 3000
    vim.defer_fn(function()
      pcall(vim.api.nvim_win_close, win, true)
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end, timeout)
  end)

  return msg
end