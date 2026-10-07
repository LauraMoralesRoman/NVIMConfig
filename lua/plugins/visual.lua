return {
  {
    'nyoom-engineering/oxocarbon.nvim',
    build = false,
    -- Add in any other configuration;
    --   event = foo,
    --   config = bar
    --   end,
  },
  {
    'vague-theme/vague.nvim',
  },
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = { 'BufReadPost', 'BufNewFile' },
  },
  { 'junegunn/vim-peekaboo' },
  {
    'chentoast/marks.nvim',
    event = 'VeryLazy',
    opts = {},
  },
  {
    'lewis6991/satellite.nvim',
    event = 'VeryLazy',

    opts = {
      -- Only show the scrollbar in the currently focused window.
      current_only = true,

      -- Transparency of the scrollbar.
      winblend = 50,

      -- Width of the scrollbar.
      width = 2,

      handlers = {
        -- Show the current cursor position.
        cursor = {
          enable = true,
        },

        -- Show search matches.
        search = {
          enable = true,
        },

        -- Show LSP diagnostics.
        diagnostic = {
          enable = true,
          min_severity = vim.diagnostic.severity.HINT,
        },

        -- Show Git changes from gitsigns.nvim.
        gitsigns = {
          enable = true,
        },

        -- Show Vim marks.
        marks = {
          enable = true,

          -- Don't show builtin marks such as [, ], < and >.
          show_builtins = false,
        },

        -- Show quickfix locations.
        quickfix = {
          enable = true,
        },
      },
    },
  },
}
