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
      local dapui_util = require 'dapui.util'

      ---------------------------------------------------------------------------
      -- GDB COMMAND BUFFER
      ---------------------------------------------------------------------------
      --
      -- Persistent, in-memory, user-editable GDB command buffer.
      --
      -- Example:
      --
      --   # Settings
      --   set pagination off
      --   set print pretty on
      --
      --   # Breakpoints
      --   break main
      --   break MyNamespace::MyClass::method
      --
      ---------------------------------------------------------------------------

      local gdb_commands = {
        buffer = dapui_util.create_buffer('GDB Commands', {
          filetype = 'dapui_gdb_commands',
        }),

        float_defaults = function()
          return {
            enter = true,
          }
        end,
      }

      local gdb_commands_bufnr = gdb_commands.buffer()

      ---------------------------------------------------------------------------
      -- The buffer belongs to the user.
      ---------------------------------------------------------------------------

      vim.bo[gdb_commands_bufnr].modifiable = true
      vim.bo[gdb_commands_bufnr].readonly = false
      vim.bo[gdb_commands_bufnr].buftype = 'nofile'
      vim.bo[gdb_commands_bufnr].bufhidden = 'hide'
      vim.bo[gdb_commands_bufnr].swapfile = false

      ---------------------------------------------------------------------------
      -- Never let dapui overwrite the contents.
      ---------------------------------------------------------------------------

      function gdb_commands.render()
        -- Intentionally empty.
      end

      ---------------------------------------------------------------------------
      -- DAP UI
      ---------------------------------------------------------------------------

      dapui.setup {
        layouts = {
          {
            elements = {
              { id = 'scopes', size = 0.25 },
              { id = 'breakpoints', size = 0.20 },
              { id = 'stacks', size = 0.25 },
              { id = 'watches', size = 0.15 },
              { id = 'gdb_commands', size = 0.15 },
            },

            size = 40,
            position = 'left',
          },

          {
            elements = {
              { id = 'repl', size = 0.5 },
              { id = 'console', size = 0.5 },
            },

            size = 10,
            position = 'bottom',
          },
        },

        controls = {
          enabled = true,
          element = 'repl',

          icons = {
            pause = '',
            play = '',
            step_into = '',
            step_over = '',
            step_out = '',
            step_back = '',
            run_last = '',
            terminate = '',
          },
        },
      }

      dapui.register_element('gdb_commands', gdb_commands)

      ---------------------------------------------------------------------------
      -- GDB COMMAND HELPERS
      ---------------------------------------------------------------------------

      local function get_gdb_commands()
        local bufnr = gdb_commands.buffer()

        if not vim.api.nvim_buf_is_valid(bufnr) then
          return {}
        end

        return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      end

      ---------------------------------------------------------------------------
      -- Execute one GDB CLI command.
      --
      -- GDB DAP treats evaluate/repl as a GDB CLI command.
      ---------------------------------------------------------------------------

      local function execute_gdb_command(session, command, callback)
        command = vim.trim(command)

        if command == '' or vim.startswith(command, '#') then
          if callback then
            callback()
          end

          return
        end

        session:request('evaluate', {
          expression = command,
          context = 'repl',
        }, function(err)
          if err then
            vim.schedule(function()
              vim.notify('GDB command failed:\n' .. command .. '\n\n' .. vim.inspect(err), vim.log.levels.WARN)
            end)
          end

          if callback then
            callback()
          end
        end)
      end

      ---------------------------------------------------------------------------
      -- Execute commands SEQUENTIALLY.
      --
      -- This is important.
      --
      -- We don't fire all evaluate requests at once. The next command isn't
      -- sent until GDB has responded to the previous one.
      ---------------------------------------------------------------------------

      local function execute_gdb_commands_sequentially(session, lines, index)
        index = index or 1

        if not session then
          return
        end

        if dap.session() ~= session then
          return
        end

        if index > #lines then
          vim.schedule(function()
            vim.notify('GDB initialization commands completed', vim.log.levels.INFO)
          end)

          return
        end

        execute_gdb_command(session, lines[index], function()
          execute_gdb_commands_sequentially(session, lines, index + 1)
        end)
      end

      ---------------------------------------------------------------------------
      -- Execute all commands currently in the buffer.
      ---------------------------------------------------------------------------

      local function execute_all_gdb_commands(session)
        if not session then
          return
        end

        local lines = get_gdb_commands()

        execute_gdb_commands_sequentially(session, lines, 1)
      end

      ---------------------------------------------------------------------------
      -- MANUAL GDB COMMAND EXECUTION
      ---------------------------------------------------------------------------

      ---------------------------------------------------------------------------
      -- <CR>
      --
      -- Execute the current line.
      ---------------------------------------------------------------------------

      vim.keymap.set('n', '<CR>', function()
        local session = dap.session()

        if not session then
          vim.notify('No active DAP session', vim.log.levels.WARN)

          return
        end

        if session.config.type ~= 'gdb' then
          vim.notify('Current DAP session is not GDB', vim.log.levels.WARN)

          return
        end

        execute_gdb_command(session, vim.api.nvim_get_current_line())
      end, {
        buffer = gdb_commands_bufnr,
        desc = 'GDB: Execute current line',
      })

      ---------------------------------------------------------------------------
      -- <leader>r
      --
      -- Execute all commands manually.
      ---------------------------------------------------------------------------

      vim.keymap.set('n', '<leader>r', function()
        local session = dap.session()

        if not session then
          vim.notify('No active DAP session', vim.log.levels.WARN)

          return
        end

        if session.config.type ~= 'gdb' then
          vim.notify('Current DAP session is not GDB', vim.log.levels.WARN)

          return
        end

        execute_all_gdb_commands(session)
      end, {
        buffer = gdb_commands_bufnr,
        desc = 'GDB: Execute all commands',
      })

      ---------------------------------------------------------------------------
      -- GDB ADAPTER
      ---------------------------------------------------------------------------

      dap.adapters.gdb = {
        type = 'executable',

        command = 'gdb',

        args = {
          '-i',
          'dap',
        },
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

          -----------------------------------------------------------------------
          -- IMPORTANT
          --
          -- Stop before normal execution begins.
          --
          -- This gives us a stopped inferior on which the GDB command buffer
          -- can safely install symbolic breakpoints.
          -----------------------------------------------------------------------

          stopOnEntry = true,

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
      -- Automatically execute GDB commands when the session is initialized.
      --
      -- Because stopOnEntry=true, GDB has already received the program via the
      -- DAP launch request and stopped at its entry point.
      --
      -- Therefore:
      --
      --     break Foo::bar
      --
      -- now has a symbol table available and doesn't produce:
      --
      --     No symbol table is loaded.
      ---------------------------------------------------------------------------

      dap.listeners.after.event_initialized['gdb_commands'] = function(session)
        if not session then
          return
        end

        if session.config.type ~= 'gdb' then
          return
        end

        vim.schedule(function()
          if dap.session() ~= session then
            return
          end

          execute_all_gdb_commands(session)
        end)
      end

      ---------------------------------------------------------------------------
      -- Automatically open DAP UI.
      ---------------------------------------------------------------------------

      dap.listeners.after.event_initialized['dapui_config'] = function()
        dapui.open()
      end

      ---------------------------------------------------------------------------
      -- Continue / Start
      ---------------------------------------------------------------------------

      vim.keymap.set('n', '<leader>dc', function()
        dap.continue()
      end, {
        desc = 'DAP: Continue / Start',
      })

      ---------------------------------------------------------------------------
      -- Breakpoint
      ---------------------------------------------------------------------------

      vim.keymap.set('n', '<leader>db', function()
        dap.toggle_breakpoint()
      end, {
        desc = 'DAP: Toggle breakpoint',
      })

      ---------------------------------------------------------------------------
      -- Conditional breakpoint
      ---------------------------------------------------------------------------

      vim.keymap.set('n', '<leader>dB', function()
        dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end, {
        desc = 'DAP: Conditional breakpoint',
      })

      ---------------------------------------------------------------------------
      -- Step over
      ---------------------------------------------------------------------------

      vim.keymap.set('n', '<leader>do', function()
        dap.step_over()
      end, {
        desc = 'DAP: Step over',
      })

      ---------------------------------------------------------------------------
      -- Step into
      ---------------------------------------------------------------------------

      vim.keymap.set('n', '<leader>di', function()
        dap.step_into()
      end, {
        desc = 'DAP: Step into',
      })

      ---------------------------------------------------------------------------
      -- Step out
      ---------------------------------------------------------------------------

      vim.keymap.set('n', '<leader>du', function()
        dap.step_out()
      end, {
        desc = 'DAP: Step out',
      })

      ---------------------------------------------------------------------------
      -- Terminate
      ---------------------------------------------------------------------------

      vim.keymap.set('n', '<leader>dt', function()
        dap.terminate()
        dapui.close()
      end, {
        desc = 'DAP: Terminate',
      })

      ---------------------------------------------------------------------------
      -- REPL
      ---------------------------------------------------------------------------

      vim.keymap.set('n', '<leader>dr', function()
        dap.repl.open()
      end, {
        desc = 'DAP: Open REPL',
      })

      ---------------------------------------------------------------------------
      -- Toggle DAP UI
      ---------------------------------------------------------------------------

      vim.keymap.set('n', '<leader>dd', function()
        dapui.toggle()
      end, {
        desc = 'DAP: Toggle DAP UI',
      })

      ---------------------------------------------------------------------------
      -- Run to cursor
      ---------------------------------------------------------------------------

      vim.keymap.set('n', '<leader>dh', function()
        dap.run_to_cursor()
      end, {
        desc = 'DAP: Run to cursor',
      })

      ---------------------------------------------------------------------------
      -- DAP REPL completion
      ---------------------------------------------------------------------------

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

      ---------------------------------------------------------------------------
      -- Clear breakpoints
      ---------------------------------------------------------------------------

      vim.api.nvim_create_user_command('ClearBreakpoints', dap.clear_breakpoints, {
        desc = 'Clear all DAP breakpoints',
      })

      ---------------------------------------------------------------------------
      -- Open GDB Commands in a floating window.
      ---------------------------------------------------------------------------

      vim.api.nvim_create_user_command('DapGdbCommands', function()
        dapui.float_element('gdb_commands', {
          enter = true,
        })
      end, {
        desc = 'Open GDB command buffer',
      })
    end,
  },
}
