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
        'kevinhwang91/rnvimr',
        cmd = 'RnvimrToggle', -- lazy-load when you run the command
        opts = {
            -- layout options:
            border = 'double',
            width = 0.9,
            height = 0.6,
            -- behavior tweaks:
            replace_netrw = true,
            auto_resize = true,
            hide_cursor = true,
        },
        config = function() end,
        keys = {
            { '<leader>r', mode = 'n', '<cmd>RnvimrToggle<cr>' },
        },
    },
}
