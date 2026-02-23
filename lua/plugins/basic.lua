return {
	'mrjones2014/smart-splits.nvim',
  {
    'junegunn/fzf.vim',
    dependencies = { 'junegunn/fzf' },
    keys = {
      { '<Leader><Leader>', '<cmd>FzfLua files<cr>', desc = 'Find files' },
      { '<Leader>,', '<cmd>FzfLua buffers<cr>', desc = 'Find buffers' },
      { '<Leader>/', '<cmd>FzfLua live_grep<cr>', desc = 'Search project' },
      { '<Leader>lw', '<cmd>FzfLua lsp_workspace_symbols<cr>', desc = 'Search symbols in workspace' },
      { '<Leader>ls', '<cmd>FzfLua lsp_document_symbols<cr>', desc = 'Search symbols in document' },
      { '<Leader>lh', '<cmd>LspClangdSwitchSourceHeader<cr>', desc = 'Switch between source and header' },
      { '<Leader>lu', '<cmd>FzfLua lsp_references<cr>', desc = 'Search references to symbol' },
      { 'gd', '<cmd>FzfLua lsp_definitions<cr>', desc = 'Search definitions' },
      { '<Leader>.', '<cmd>FzfLua lines<cr>', desc = 'Search lines in the current buffer' },
    },
    config = function()
      require('fzf-lua').setup {
        keymap = {
          fzf = {
            ['ctrl-q'] = 'select-all+accept',
          },
        },
        winopts = {
            split = "botright 10new",
            border = 'none',
            width = 1,
            row = 0,
            col = 0,
            preview = {
                layout = "horizontal",
                hidden = "hidden"
            }
        },
        fzf_opts = {
            ['--no-info'] = '',      -- Hide the "10/100" count
            ['--info'] = 'hidden',   -- Alternative way to hide info
            ['--header'] = ' ',      -- Hide the helper text (ctrl-c, etc.)
            ['--no-scrollbar'] = '', -- Hide scrollbar
          }
      }
	  require("fzf-lua").register_ui_select()
    end,
formatters_by_ft = {
  lua = { 'stylua' },
  rust = { 'rustfmt' },        -- Standard Rust formatter
  c = { 'clang-format' },      -- Clang-format for C
  cpp = { 'clang-format' },    -- Clang-format for C++
}
  },
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim', -- required
      'sindrets/diffview.nvim', -- optional - Diff integration

      'ibhagwan/fzf-lua', -- optional
    },
    config = true,
  },
  {
    'lewis6991/gitsigns.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
  },
  {
    'skywind3000/asyncrun.vim',
    cmd = { 'AsyncRun', 'AsyncStop' }, -- load only when you use these commands
    config = function()
      -- Open the quickfix window automatically with 6 lines height
      vim.g.asyncrun_open = 6
      -- Save current file before running
      vim.g.asyncrun_save = 1
    end,
  },
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = true,
  },
    {
        'stevearc/oil.nvim',
        ---@module 'oil'
        ---@type oil.SetupOpts
        opts = {
            float = {
                padding = 2,
                max_width = 0.4,
                max_height = 0.4,
                border = 'rounded'
            },
            keymaps = {
                ["q"] = "actions.close", -- press q to close the Oil buffer :contentReference[oaicite:2]{index=2}
            },
        },
        -- Optional dependencies
        dependencies = { { "echasnovski/mini.icons", opts = {} } },
        -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
        -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
        lazy = false,
        keys = {
            { '-',         '<cmd>Oil --float<cr>',   desc = 'Shows file explorer' },
            { '<Leader>-', '<cmd>Oil --float .<cr>', desc = 'Shows file explorer at the root directory' }
        }
    }
}
