return {
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      'mfussenegger/nvim-dap-ui',
      'LiadOz/nvim-dap-repl-highlights',
    },
    event = 'VeryLazy',
    config = function()
      local dap = require 'dap'
      local dapui = require 'dap-ui'

      dapui.setup {
        layouts = {
          {
            positions = { bottom = '40%' },
            size = 40,
          },
        },
      }

      -- codelldb covers C, C++, Rust (and Odin via nvim-dap-odin)
      dap.adapters.codelldb = {
        type = 'server',
        port = '${port}',
        executable = {
          command = vim.env.CODELLDB_PATH or 'codelldb',
          args = { '--port', '${port}' },
        },
      }

      -- Python via debugpy (install with: pip install debugpy)
      dap.adapters.python = {
        type = 'executable',
        command = vim.env.PYDEBUGPY_PATH or vim.fn.exepath('python3'),
        args = { '-m', 'debugpy.adapter' },
      }

      dap.configurations.c = {
        {
          name = 'Launch',
          type = 'codelldb',
          request = 'launch',
          program = function()
            return vim.fn.input('Path to executable: ', vim.current.buffer.name, 'file')
          end,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
          args = {},
        },
      }

      dap.configurations.cpp = dap.configurations.c
      dap.configurations.cs = dap.configurations.c

      dap.configurations.rust = {
        {
          name = 'Launch',
          type = 'codelldb',
          request = 'launch',
          program = function()
            return vim.fn.input('Path to executable: ', vim.current.buffer.name, 'file')
          end,
          cwd = '${workspaceFolder}',
          args = {},
          stopOnEntry = false,
          runInTerminal = false,
        },
      }

      dap.configurations.python = {
        {
          type = 'python',
          request = 'launch',
          name = 'Launch file',
          program = '${file}',
          pythonPath = function()
            local current = vim.fn.expand '%:p:h'
            local candidates = {
              current .. '/.venv/bin',
              current .. '/venv/bin',
              current .. '/.venv/bin',
              os.getenv('HOME') .. '/.virtualenvs/bin',
            }
            for _, c in ipairs(candidates) do
              local python = c .. '/python3'
              if vim.fn.executable(python) == 1 then
                return python
              end
            end
            return 'python3'
          end,
        },
      }

      -- nvim-dap-odin registers its own Odin configurations (type = 'codelldb')
      -- once installed; no manual config needed.

      dapui.setup()

      -- Leader-d keybindings: <leader>d as prefix, never function keys
      local keys = {
        { '<leader>db', function() dap.toggle_breakpoint() end, desc = 'DAP Toggle Breakpoint' },
        { '<leader>dB', function() dap.set_breakpoint() end, desc = 'DAP Set Breakpoint' },
        { '<leader>dc', function() dap.continue() end, desc = 'DAP Continue' },
        { '<leader>di', function() dap.step_in() end, desc = 'DAP Step In' },
        { '<leader>do', function() dap.step_out() end, desc = 'DAP Step Out' },
        { '<leader>dn', function() dap.step_over() end, desc = 'DAP Step Over' },
        { '<leader>du', function() dapui.toggle() end, desc = 'DAP Toggle UI' },
        { '<leader>dr', function() dap.repl.open() end, desc = 'DAP Open REPL' },
        { '<leader>dR', function() dap.restart() end, desc = 'DAP Restart' },
        { '<leader>dh', function() dapui.help() end, desc = 'DAP Help' },
      }

      -- Bind keymaps (the plugin is already loaded by the time config runs)
      for _, k in ipairs(keys) do
        vim.keymap.set('n', k[1], k[2], { desc = k.desc, noremap = true, silent = true })
      end
    end,
  },
}
