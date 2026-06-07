-- hermes-bridge/notify.lua
-- Replaces vim.notify with a minimal bottom-right notification system.
--
-- Displays floating windows at the bottom-right of the editor with:
--   - INFO:  blue (#7aa2f7)  with icon 
--   - WARN:  yellow (#e0af68) with icon 
--   - ERROR: red (#f7768e)  with icon 
-- Auto-dismisses after 3 seconds.
--
-- Color values match the Kanagawa theme used by this config.

local icons = {
  [vim.log.levels.INFO]  = " ",
  [vim.log.levels.WARN]  = " ",
  [vim.log.levels.ERROR] = " ",
}

local colors = {
  [vim.log.levels.INFO]  = "#7aa2f7",
  [vim.log.levels.WARN]  = "#e0af68",
  [vim.log.levels.ERROR] = "#f7768e",
}

-- Preserve original vim.notify
if not _G._original_vim_notify then
  _G._original_vim_notify = vim.notify
end

--- Override vim.notify with a floating window at bottom-right.
--- Falls back to the original notify if the UI is not available (headless).
---@param msg string  The message text
---@param log_level number|nil  vim.log.levels.INFO/WARN/ERROR (default: INFO)
---@param _opts table|nil  Unused (ignored for compatibility)
---@return string msg
vim.notify = function(msg, log_level, _opts)
  log_level = log_level or vim.log.levels.INFO
  local icon = icons[log_level] or " "
  local color = colors[log_level] or "#7aa2f7"

  vim.schedule(function()
    -- Build the display string
    local display = icon .. msg

    -- Get UI dimensions
    local ui = vim.api.nvim_list_uis()[1]
    if not ui then
      -- Headless or no UI — fallback to print
      if _G._original_vim_notify then
        _G._original_vim_notify(msg, log_level)
      else
        print(msg)
      end
      return
    end

    -- Create scratch buffer for the notification
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { display })

    -- Calculate position
    local width = math.min(#display + 2, ui.width - 2)
    local height = 1

    -- Open floating window at bottom-right
    local win = vim.api.nvim_open_win(buf, false, {
      relative = "editor",
      width = width,
      height = height,
      row = ui.height - 3,
      col = ui.width - width - 1,
      style = "minimal",
      border = "none",
      zindex = 50,
    })

    -- Set the window highlight to the level colour
    vim.api.nvim_set_option_value("winhl", "NormalFloat:Normal", { win = win })

    -- Auto-close after 3 seconds (5 for errors)
    local timeout = log_level == vim.log.levels.ERROR and 5000 or 3000
    vim.defer_fn(function()
      pcall(vim.api.nvim_win_close, win, true)
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end, timeout)
  end)

  return msg
end