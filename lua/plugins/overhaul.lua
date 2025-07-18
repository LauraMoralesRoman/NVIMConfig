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
            { '-', '<cmd>Oil --float<cr>', desc = 'Shows file explorer' }
        }
    }
}
