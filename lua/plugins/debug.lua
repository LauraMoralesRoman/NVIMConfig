return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "williamboman/mason.nvim", -- ensure mason is loaded first
    },
    ft = { "c", "cpp", "zig" },
    config = function()
      local dap   = require("dap")
      local dapui = require("dapui")

      -- ─── UI Setup ─────────────────────────────────────────────────
      dapui.setup({
        icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
        layouts = {
          {
            elements = {
              { id = "scopes",      size = 0.35 },
              { id = "breakpoints", size = 0.15 },
              { id = "stacks",      size = 0.3  },
              { id = "watches",     size = 0.2  },
            },
            size     = 40,
            position = "left",
          },
          {
            elements = {
              { id = "repl",    size = 0.5 },
              { id = "console", size = 0.5 },
            },
            size     = 12,
            position = "bottom",
          },
        },
      })

      -- ─── UI auto open/close ───────────────────────────────────────
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      -- ─── Keymaps ──────────────────────────────────────────────────
      local map = vim.keymap.set
      map("n", "<leader>dc",        dap.continue,             { desc = "DAP: Continue" })
      map("n", "<leader>so",        dap.step_over,             { desc = "DAP: Step Over" })
      map("n", "<leader>si",        dap.step_into,             { desc = "DAP: Step Into" })
      map("n", "<leader>so",        dap.step_out,              { desc = "DAP: Step Out" })
      map("n", "<leader>db",  dap.toggle_breakpoint,     { desc = "DAP: Toggle Breakpoint" })
      map("n", "<leader>dB",  function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end,                                               { desc = "DAP: Conditional Breakpoint" })
      map("n", "<leader>dr",  dap.repl.open,             { desc = "DAP: Open REPL" })
      map("n", "<leader>dl",  dap.run_last,              { desc = "DAP: Run Last" })
      map("n", "<leader>dx",  dap.terminate,             { desc = "DAP: Terminate" })
      map("n", "<leader>du",  dapui.toggle,              { desc = "DAP: Toggle UI" })

      -- ─── GDB adapter (GDB >= 14.1) ────────────────────────────────
      if vim.fn.executable("gdb") == 1 then
        dap.adapters.gdb = {
          id      = "gdb",
          type    = "executable",
          command = "gdb",
          args    = { "--quiet", "--interpreter=dap" },
        }

        local gdb_config = {
          {
            name    = "Launch executable (GDB)",
            type    = "gdb",
            request = "launch",
            program = function()
              local path = vim.fn.input({
                prompt     = "Path to executable: ",
                default    = vim.fn.getcwd() .. "/",
                completion = "file",
              })
              return (path ~= "") and path or dap.ABORT
            end,
          },
          {
            name    = "Launch with arguments (GDB)",
            type    = "gdb",
            request = "launch",
            program = function()
              local path = vim.fn.input({
                prompt     = "Path to executable: ",
                default    = vim.fn.getcwd() .. "/",
                completion = "file",
              })
              return (path ~= "") and path or dap.ABORT
            end,
            args = function()
              return vim.split(vim.fn.input({ prompt = "Arguments: " }), " +")
            end,
          },
          {
            name      = "Attach to process (GDB)",
            type      = "gdb",
            request   = "attach",
            processId = require("dap.utils").pick_process,
          },
        }

        dap.configurations.c   = gdb_config
        dap.configurations.cpp = gdb_config
      end

      -- ─── codelldb adapter (Zig) ───────────────────────────────────
      local ok, mason_registry = pcall(require, "mason-registry")
      local codelldb_path = (ok and mason_registry.is_installed("codelldb"))
        and mason_registry.get_package("codelldb"):get_install_path()
            .. "/extension/adapter/codelldb"
        or "codelldb"

      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = codelldb_path,
          args    = { "--port", "${port}" },
        },
      }

      dap.configurations.zig = {
        {
          name        = "Launch Zig binary (codelldb)",
          type        = "codelldb",
          request     = "launch",
          program     = "${workspaceFolder}/zig-out/bin/${workspaceFolderBasename}",
          cwd         = "${workspaceFolder}",
          stopOnEntry = false,
          args        = {},
        },
        {
          name    = "Launch Zig binary (custom path)",
          type    = "codelldb",
          request = "launch",
          program = function()
            local path = vim.fn.input({
              prompt     = "Path to Zig binary: ",
              default    = vim.fn.getcwd() .. "/zig-out/bin/",
              completion = "file",
            })
            return (path ~= "") and path or dap.ABORT
          end,
          cwd         = "${workspaceFolder}",
          stopOnEntry = false,
          args        = {},
        },
      }
    end,
  },
}

