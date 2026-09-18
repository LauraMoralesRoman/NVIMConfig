return {
  {
    'rebelot/kanagawa.nvim',
    config = {
      compile = false, -- enable compiling the colorscheme
      undercurl = true, -- enable undercurls
      commentStyle = { italic = true },
      functionStyle = {},
      keywordStyle = { italic = true },
      statementStyle = { bold = true },
      typeStyle = { bold = true },
      transparent = true, -- do not set background color
      dimInactive = false, -- dim inactive window `:h hl-NormalNC`
      terminalColors = true, -- define vim.g.terminal_color_{0,17}
      colors = { -- add/modify theme and palette colors
        palette = {},
        theme = { wave = {}, lotus = {}, dragon = {}, all = {} },
      },
      overrides = function(colors) -- add/modify highlights
        return {}
      end,
      theme = 'wave', -- Load "wave" theme
      background = { -- map the value of 'background' option to a theme
        dark = 'wave', -- try "dragon" !
        light = 'lotus',
      },
    },
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
