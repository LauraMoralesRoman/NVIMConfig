return {
  {
    'b0o/incline.nvim',
    config = function()
      require('incline').setup {
        render = function(props)
          local devicons = require 'nvim-web-devicons'
          -- Get just the filename
          local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ':t')
          if name == '' then
            name = '[No Name]'
          end

          -- Lookup icon & its GUI color
          local icon, color = devicons.get_icon_color(name, name:match '.*%.(.*)')

          -- Return a table: { { text, highlight-args }, … }
          return {
            icon and { ' ' .. icon, guifg = color } or '',
            ' ' .. name,
          }
        end,
      }
    end,
    -- Optional: Lazy load Incline
    event = 'VeryLazy',
  },
  {
    'levouh/tint.nvim', -- Dim inactive windows
    event = 'WinEnter', -- Load when entering any window :contentReference[oaicite:0]{index=0}
    opts = {
      tint = -0, -- Darken inactive windows by 45% :contentReference[oaicite:1]{index=1}
      saturation = 0.3, -- Preserve 60% of original saturation :contentReference[oaicite:2]{index=2}
      tint_background_colors = true, -- Also tint background highlight groups :contentReference[oaicite:3]{index=3}
      -- you can add `highlight_ignore_patterns` or `window_ignore_function` here too
    },
  },
  {
    'karb94/neoscroll.nvim',
    opts = {},
  },
  {
    'sphamba/smear-cursor.nvim',

    opts = {
      smear_between_buffers = not vim.g.neovide,
      smear_between_neighbor_lines = not vim.g.neovide,
      scroll_buffer_space = not vim.g.neovide,
      legacy_computing_symbols_support = false,
      smear_insert_mode = not vim.g.neovide,
    },
  },
  {
    'anuvyklack/windows.nvim',
    dependencies = { 'anuvyklack/middleclass', 'anuvyklack/animation.nvim' },
    config = function()
      vim.o.winwidth = 10
      vim.o.winminwidth = 10
      vim.o.equalalways = false
      require('windows').setup {}
    end,
    keys = {
      { '<C-w>z', '<cmd>WindowsMaximize<cr>', desc = 'Maximizes windows' },
      { '<C-w>|', '<cmd>WindowsMaximizeHorizontally<cr>', desc = 'Mazimize horizontally' },
      { '<C-w>-', '<cmd>WindowsMaximizeVertically<cr>', desc = 'Maximizes windows vertically' },
      { '<C-w>=', '<cmd>WindowsEqualize<cr>', desc = 'Maximizes windows' },
    },
  },
}
