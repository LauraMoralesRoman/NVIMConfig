return {
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
    },
    {
        'altermo/nwm',branch='x11',
        opts = {
            unfocus_map = '<C-space>'
        },
    },
    {
      "kelly-lin/ranger.nvim",
      config = function()
        require("ranger-nvim").setup({ replace_netrw = true })
        vim.api.nvim_set_keymap("n", "<leader>ef", "", {
          noremap = true,
          callback = function()
            require("ranger-nvim").open(true)
          end,
        })
      end,
    }
}
