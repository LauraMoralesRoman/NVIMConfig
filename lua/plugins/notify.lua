return {
  {
    'echasnovski/mini.nvim',
    version = false,
    config = function()
      local notify = require('mini.notify')
      notify.setup {
        -- Window options
        window = {
          -- Bottom right, minimal
          config = function()
            local has_statusline = vim.o.laststatus > 0
            local pad_footer = has_statusline and 1 or 0
            return {
              anchor = 'SE',
              col = vim.o.columns,
              row = vim.o.lines - pad_footer,
              border = 'none',
              focusable = false,
              zindex = 100,
              style = 'minimal',
            }
          end,
          -- Show for 3 seconds then auto-dismiss
          duration = 3000,
        },
        -- No icons, plain text
        content = {
          format = function(notif)
            return notif.msg
          end,
        },
        -- Max width to prevent huge popups
        max_width = 60,
      }

      -- Replace vim.notify so all plugins (including Hermes bridge) use mini.notify
      vim.notify = notify.make_notify {
        ERROR = { duration = 5000 },
        WARN  = { duration = 4000 },
        INFO  = { duration = 3000 },
        DEBUG = { duration = 0 },
        TRACE = { duration = 0 },
      }
    end,
  },
}
