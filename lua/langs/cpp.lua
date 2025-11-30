local dap = require('dap')

-- GDB with native DAP support (GDB 14.1+)
dap.adapters.gdb = {
  id = 'gdb',
  type = 'executable',
  command = 'gdb',
  args = { '--quiet', '--interpreter=dap' },
}

dap.configurations.c = {
  {
    name = 'Run executable (GDB)',
    type = 'gdb',
    request = 'launch',
    program = function()
      return vim.fn.input({
        prompt = 'Path to executable: ',
        default = vim.fn.getcwd() .. '/',
        completion = 'file',
      })
    end,
    cwd = '${workspaceFolder}',
    stopOnEntry = false,
  },
  {
    name = 'Run with arguments (GDB)',
    type = 'gdb',
    request = 'launch',
    program = function()
      return vim.fn.input({
        prompt = 'Path to executable: ',
        default = vim.fn.getcwd() .. '/',
        completion = 'file',
      })
    end,
    args = function()
      local args_str = vim.fn.input({
        prompt = 'Arguments: ',
      })
      return vim.split(args_str, ' +')
    end,
    cwd = '${workspaceFolder}',
    stopOnEntry = false,
  },
  {
    name = 'Attach to process (GDB)',
    type = 'gdb',
    request = 'attach',
    processId = require('dap.utils').pick_process,
  },
}

dap.configurations.cpp = dap.configurations.c
dap.configurations.rust = dap.configurations.c

