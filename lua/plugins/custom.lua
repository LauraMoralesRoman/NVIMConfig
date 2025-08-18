local support = require 'support'

return {
  'nyoom-engineering/oxocarbon.nvim',
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
      }
    end,
    formatters_by_ft = {
      lua = { 'stylua' },
    },
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
    'stevearc/dressing.nvim',
    opts = {
      select = {
        -- put fzf_lua first so dressing.nvim picks it for vim.ui.select()
        backend = { 'fzf_lua', 'fzf', 'builtin' },
        -- (optional) pass any fzf-lua-specific window opts here:
        fzf_lua = {
          winopts = {
            height = 0.4,
            width = 0.5,
          },
        },
      },
    },
  },
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
    'lewis6991/gitsigns.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
  },
  {
    'mozanunal/sllm.nvim',
    config = function()
      require('sllm').setup {
        -- llm_cmd = 'llm --system "Give the shortes answer possible while answering the question unless asked to elaborate. Never add code comments"',
        default_model = 'gemma3n',
        window_type = 'float',
        pick_func = function(items, opts, on_choice)
          require('fzf-lua').fzf_exec(items, {
            prompt = opts.prompt,
            winopts = { height = 0.4, width = 0.6, row = 0.3, col = 0.5 },
            fzf_opts = { ['--layout'] = 'reverse-list' },
            actions = {
              -- map <CR> to call on_choice with the first selected item
              ['default'] = function(selected)
                -- selected is a table of chosen lines
                on_choice(selected[1], 1)
              end,
            },
          })
        end,
        notify_func = vim.notify,
        input_func = function(opts, on_confirm)
          -- opts.prompt is the message to show
          local answer = vim.fn.input((opts.prompt or '') .. ' ')
          on_confirm(answer)
        end,
      }
    end,
  },
  {
    'jbyuki/venn.nvim',
    lazy = true,
    keys = {
      {
        '<leader>v',
        mode = 'n',
        function()
          if support.toggle_venn() then
            vim.notify('Activating diagram mode', vim.log.levels.INFO, {})
          else
            vim.notify('Deactivating diagram mode', vim.log.levels.INFO, {})
          end
        end,
      },
    },
  },
  {
    'jbyuki/nabla.nvim',
    dependencies = {
      'williamboman/mason.nvim',
      'nvim-neo-tree/neo-tree.nvim',
    },
    config = function()
      require('nabla').enable_virt {
        autogen = true, -- automatically find and render math expressions
        silent = true, -- don’t spam messages
      }
    end,
  },
  {
    'mbbill/undotree',
    keys = {
      {
        '<leader>u',
        mode = 'n',
        '<cmd>UndotreeToggle<cr>',
      },
    },
  },
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    opts = {
      image = {
        formats = {
          'png',
          'jpg',
          'jpeg',
          'gif',
          'bmp',
          'webp',
          'tiff',
          'heic',
          'avif',
          'mp4',
          'mov',
          'avi',
          'mkv',
          'webm',
          'pdf',
        },
        doc = {
          enabled = false,
        },
      },
      bigfile = { enabled = true },
      quickfile = {},
      statuscolumn = {},
      words = {},
      indent = {
        indent = {

          only_scope = true, -- only show indent guides of the scope
          only_current = true, -- only show indent guides in the current window
        },
        scope = {
          enabled = false,
        },
        animate = {
          enabled = false,
        },
      },
    },
  },
}
