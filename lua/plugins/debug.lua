return {
  {
    'mfussenegger/nvim-dap',

    dependencies = {
      {
        'rcarriga/nvim-dap-ui',
        dependencies = {
          'nvim-neotest/nvim-nio',
        },
      },

      {
        'jay-babu/mason-nvim-dap.nvim',
        dependencies = {
          'williamboman/mason.nvim',
        },
        opts = {
          ensure_installed = {
            'python',
            'bash',
          },
        },
      },
    },

    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'

      ---------------------------------------------------------------------------
      -- DAP UI
      ---------------------------------------------------------------------------

      dapui.setup()

      dap.listeners.after.event_initialized['dapui_config'] = function()
        dapui.open()
      end

      dap.listeners.before.event_terminated['dapui_config'] = function()
        dapui.close()
      end

      dap.listeners.before.event_exited['dapui_config'] = function()
        dapui.close()
      end

      ---------------------------------------------------------------------------
      -- GDB
      --
      -- Requires GDB 14 or newer.
      --
      -- Check with:
      --   gdb --version
      ---------------------------------------------------------------------------

      dap.adapters.gdb = {
        type = 'executable',
        command = 'gdb',
        args = { '-i', 'dap' },
      }

      ---------------------------------------------------------------------------
      -- C / C++ / Rust
      ---------------------------------------------------------------------------

      local gdb_config = {
        {
          name = 'Launch',
          type = 'gdb',
          request = 'launch',

          program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,

          cwd = '${workspaceFolder}',

          stopAtBeginningOfMainSubprogram = false,

          args = function()
            local args = vim.fn.input 'Arguments: '

            if args == '' then
              return {}
            end

            return vim.split(args, ' ', {
              trimempty = true,
            })
          end,
        },
      }

      dap.configurations.c = vim.deepcopy(gdb_config)
      dap.configurations.cpp = vim.deepcopy(gdb_config)
      dap.configurations.rust = vim.deepcopy(gdb_config)

      ---------------------------------------------------------------------------
      -- Python
      ---------------------------------------------------------------------------

      dap.configurations.python = {
        {
          name = 'Python: Launch current file',
          type = 'python',
          request = 'launch',

          program = '${file}',
          cwd = '${workspaceFolder}',

          console = 'integratedTerminal',

          pythonPath = function()
            local venv = os.getenv 'VIRTUAL_ENV'

            if venv then
              return venv .. '/bin/python'
            end

            return vim.fn.exepath 'python3'
          end,
        },
      }

      ---------------------------------------------------------------------------
      -- Bash
      ---------------------------------------------------------------------------

      dap.configurations.sh = {
        {
          name = 'Bash: Launch current file',
          type = 'bash',
          request = 'launch',

          program = '${file}',
          cwd = '${fileDirname}',

          terminalKind = 'integrated',
        },
      }

      dap.configurations.bash = dap.configurations.sh

      ---------------------------------------------------------------------------
      -- Keymaps
      ---------------------------------------------------------------------------

      vim.keymap.set('n', '<leader>dc', function()
        dap.continue()
      end, { desc = 'DAP: Continue / Start' })

      vim.keymap.set('n', '<leader>db', function()
        dap.toggle_breakpoint()
      end, { desc = 'DAP: Toggle breakpoint' })

      vim.keymap.set('n', '<leader>do', function()
        dap.step_over()
      end, { desc = 'DAP: Step over' })

      vim.keymap.set('n', '<leader>di', function()
        dap.step_into()
      end, { desc = 'DAP: Step into' })

      vim.keymap.set('n', '<leader>du', function()
        dap.step_out()
      end, { desc = 'DAP: Step out' })

      vim.keymap.set('n', '<leader>dt', function()
        dap.terminate()
      end, { desc = 'DAP: Terminate' })

      vim.keymap.set('n', '<leader>dr', function()
        dap.repl.open()
      end, { desc = 'DAP: Open REPL' })

      vim.keymap.set('n', '<leader>dd', function()
        dapui.toggle()
      end, { desc = 'DAP: Toggle DAP UI' })

      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'dap-repl',
        callback = function(args)
          vim.bo[args.buf].omnifunc = "v:lua.require'dap.repl'.omnifunc"

          vim.keymap.set('i', '<Tab>', function()
            if vim.fn.pumvisible() == 1 then
              return '<C-n>'
            end

            return '<C-x><C-o>'
          end, {
            buffer = args.buf,
            expr = true,
            replace_keycodes = true,
            desc = 'DAP completion',
          })
        end,
      })
    end,
  },
}
