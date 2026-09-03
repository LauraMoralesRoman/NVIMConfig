return {
  {
    'ziontee113/icon-picker.nvim',
    dependencies = { 'ibhagwan/fzf-lua' },
    config = function()
      require('icon-picker').setup { disable_legacy_commands = true }
    end,
    cmd = {
      'IconPickerInsert',
      'IconPickerNormal',
      'IconPickerYank',
    },
  },
  {
    'smjonas/live-command.nvim',
    event = 'VeryLazy',
    config = function()
      require('live-command').setup {
        commands = {
          Norm = { cmd = 'norm' },
        },
      }
    end,
  },
  {
    'gelguy/wilder.nvim',
    event = 'CmdlineEnter',
    dependencies = {
      'romgrk/fzy-lua-native',
    },
    config = function()
      local wilder = require 'wilder'
      wilder.setup { modes = { ':', '/', '?' } }

      wilder.set_option('pipeline', {
        wilder.branch(
          wilder.cmdline_pipeline {
            fuzzy = 1,
            set_pcre2_pattern = 1,
          },
          wilder.search_pipeline()
        ),
      })

      local horizontal_renderer = wilder.wildmenu_renderer {
        highlighter = wilder.lua_fzy_highlighter(),
        separator = ' · ',
        left = { ' ', wilder.wildmenu_spinner(), ' ' },
        right = { ' ', wilder.wildmenu_index() },
      }

      local search_renderer = wilder.wildmenu_renderer {
        highlighter = wilder.lua_fzy_highlighter(),
        separator = ' · ',
        left = { ' ', wilder.wildmenu_spinner(), ' ' },
        right = { ' ', wilder.wildmenu_index() },
      }

      wilder.set_option(
        'renderer',
        wilder.renderer_mux {
          [':'] = horizontal_renderer, -- vertical popupmenu with icons
          ['/'] = search_renderer, -- horizontal for search
          ['?'] = search_renderer,
        }
      )
    end,
  },
  {
    'nvzone/menu',
    lazy = true,
    dependencies = {
      'nvzone/volt',
      'nvzone/minty',
    },
    keys = {
      {
        '<C-t>',
        mode = 'n',
        function()
          require('menu').open 'default'
        end,
      },
    },
  },
  { 'rafamadriz/friendly-snippets' },
  {
    'nvim-neotest/neotest',
    cmd = 'Neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'antoinemadec/FixCursorHold.nvim',

      -- Test runners
      'orjangj/neotest-ctest',
      'lawrence-laz/neotest-zig',
      'rouge8/neotest-rust',
    },
    config = function()
      require('neotest').setup {
        adapters = {
          require('neotest-ctest').setup {},
          require 'neotest-zig' {
            dap = {
              adapter = 'lldb',
            },
          },
          require 'neotest-rust' {
            args = { '--no-capture' },
          },
        },
      }
    end,
  },
  {
    'luckasRanarison/nvim-devdocs',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    cmd = {
      'DevdocsOpen',
      'DevdocsFetch',
      'DevdocsToggle',
      'DevdocsUpdate',
      'DevdocsInstall',
      'DevdocsOpenFloat',
      'DevdocsUninstall',
      'DevdocsUpdataAll',
      'DevdocsKeywordprg',
      'DevdocsOpenCurrent',
      'DevdocsOpenCurrentFloat',
    },
    opts = {},
  },
}
