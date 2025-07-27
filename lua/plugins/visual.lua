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
    config = function()
      require('neoscroll.config').set_mappings {
        ['<C-u>'] = { 'scroll', { '-vim.wo.scroll', 'true', 100 } }, -- 100 ms half‑page up :contentReference[oaicite:17]{index=17}
        ['<C-d>'] = { 'scroll', { 'vim.wo.scroll', 'true', 100 } }, -- 100 ms half‑page down :contentReference[oaicite:18]{index=18}
        ['<C-b>'] = { 'scroll', { '-vim.api.nvim_win_get_height(0)', 'true', 200 } }, -- 200 ms full page up :contentReference[oaicite:19]{index=19}
        ['<C-f>'] = { 'scroll', { 'vim.api.nvim_win_get_height(0)', 'true', 200 } }, -- 200 ms full page down :contentReference[oaicite:20]{index=20}
      }
    end,
  },
  {
    'sphamba/smear-cursor.nvim',

    opts = {
      smear_between_buffers = not vim.g.neovide,
      smear_between_neighbor_lines = not vim.g.neovide,
      -- scroll_buffer_space = not vim.g.neovide,
      scroll_buffer_space = false,
      legacy_computing_symbols_support = false,
      smear_insert_mode = not vim.g.neovide,
      -- lower the draw interval (default 17 ms)
      time_interval = 7, -- ms between frames, smaller = smoother :contentReference[oaicite:3]{index=3}

      -- increase spring stiffness (default 0.6 → 0.8) for snappier motion
      stiffness = 0.8, -- [0,1] :contentReference[oaicite:4]{index=4}
      trailing_stiffness = 0.7, -- [0,1] :contentReference[oaicite:5]{index=5}

      -- adjust damping (default 0.65 → 0.8) to reduce overshoot
      damping = 0.8, -- [0,1] :contentReference[oaicite:6]{index=6}
      damping_insert_mode = 0.8, -- [0,1] :contentReference[oaicite:7]{index=7}
    },
  },
  {
    'anuvyklack/windows.nvim',
    dependencies = { 'anuvyklack/middleclass', 'anuvyklack/animation.nvim' },
    lazy = false,
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
