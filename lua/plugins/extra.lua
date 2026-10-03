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
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    },
    keys = {
      {
        '<leader>?',
        function()
          require('which-key').show { global = false }
        end,
        desc = 'Buffer Local Keymaps (which-key)',
      },
    },
  },
  {
    'jbyuki/venn.nvim',
    config = function()
      -- venn.nvim: enable or disable keymappings
      function _G.Toggle_venn()
        local venn_enabled = vim.inspect(vim.b.venn_enabled)
        if venn_enabled == 'nil' then
          vim.b.venn_enabled = true
          vim.cmd [[setlocal ve=all]]
          -- draw a line on HJKL keystokes
          vim.api.nvim_buf_set_keymap(0, 'n', 'J', '<C-v>j:VBox<CR>', { noremap = true })
          vim.api.nvim_buf_set_keymap(0, 'n', 'K', '<C-v>k:VBox<CR>', { noremap = true })
          vim.api.nvim_buf_set_keymap(0, 'n', 'L', '<C-v>l:VBox<CR>', { noremap = true })
          vim.api.nvim_buf_set_keymap(0, 'n', 'H', '<C-v>h:VBox<CR>', { noremap = true })
          -- draw a box by pressing "f" with visual selection
          vim.api.nvim_buf_set_keymap(0, 'v', 'f', ':VBox<CR>', { noremap = true })
        else
          vim.cmd [[setlocal ve=]]
          vim.api.nvim_buf_del_keymap(0, 'n', 'J')
          vim.api.nvim_buf_del_keymap(0, 'n', 'K')
          vim.api.nvim_buf_del_keymap(0, 'n', 'L')
          vim.api.nvim_buf_del_keymap(0, 'n', 'H')
          vim.api.nvim_buf_del_keymap(0, 'v', 'f')
          vim.b.venn_enabled = nil
        end
      end
      -- toggle keymappings for venn using <leader>v
      vim.api.nvim_set_keymap('n', '<leader>v', ':lua Toggle_venn()<CR>', { noremap = true })
    end,
  },
}
