return {
  {
    'ziontee113/icon-picker.nvim',
    config = function()
      require('icon-picker').setup { disable_legacy_commands = true }
    end,
    commands = {
      'IconPickerInsert',
      'IconPickerNormal',
      'IconPickerYank',
    },
  },
  {
      'smjonas/live-command.nvim',
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
  lazy = false,
  dependencies = {
	"romgrk/fzy-lua-native"
  },
  config = function()
    local wilder = require('wilder')
    wilder.setup({ modes = { ':', '/', '?' } })

    wilder.set_option('pipeline', {
      wilder.branch(
        wilder.cmdline_pipeline({
          fuzzy = 1,
          set_pcre2_pattern = 1,
        }),
        wilder.search_pipeline()
      ),
    })

	local horizontal_renderer = wilder.wildmenu_renderer({
	  highlighter = wilder.lua_fzy_highlighter(),
	  separator = ' · ',
	  left = { ' ', wilder.wildmenu_spinner(), ' ' },
	  right = { ' ', wilder.wildmenu_index() },
	})


    local search_renderer = wilder.wildmenu_renderer({
      highlighter = wilder.lua_fzy_highlighter(),
      separator = ' · ',
      left = { ' ', wilder.wildmenu_spinner(), ' ' },
      right = { ' ', wilder.wildmenu_index() },
    })

    wilder.set_option('renderer', wilder.renderer_mux({
      [':'] = horizontal_renderer,  -- vertical popupmenu with icons
      ['/'] = search_renderer,   -- horizontal for search
      ['?'] = search_renderer,
    }))
  end
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
					end
				}
			}
	},
  {
  "jla2000/lazydocs.nvim",
  event = "VeryLazy",
  dependencies = {
    "L3MON4D3/LuaSnip",
    "nvimtools/none-ls.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {},
},
  {
    'gsuuon/note.nvim',
    opts = {},
    cmd = 'Note',
    ft = 'note',
    config = function(_, opts)
      require('note').setup(opts)
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'note',
        callback = function()
          vim.bo.textwidth = 80
        end,
      })
    end,
  },
}
