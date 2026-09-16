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

      local vertical_renderer = wilder.popupmenu_renderer {
        highlighter = wilder.lua_fzy_highlighter(),
        left = {
          ' ',
          wilder.popupmenu_devicons(),
          ' ',
        },
        right = {
          ' ',
          wilder.popupmenu_scrollbar(),
        },
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
          [':'] = vertical_renderer, -- vertical popupmenu with icons
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
}
