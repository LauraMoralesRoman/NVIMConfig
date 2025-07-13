return {
    {
        'baliestri/aura-theme',
        lazy = false,
        priority = 1000,
        config = function(plugin)
            vim.opt.rtp:append(plugin.dir .. '/packages/neovim')
            -- vim.cmd [[colorscheme aura-dark-soft-text]]
        end,
    },
    {
        'junegunn/fzf.vim',
        dependencies = { 'junegunn/fzf' },
        keys = {
            { '<Leader><Leader>', '<cmd>Files<cr>',   desc = 'Find files' },
            { '<Leader>,',        '<cmd>Buffers<cr>', desc = 'Find buffers' },
            { '<Leader>/',        '<cmd>Rg<cr>',      desc = 'Search project' },
        },
    },
    {
        'NeogitOrg/neogit',
        dependencies = {
            'nvim-lua/plenary.nvim',  -- required
            'sindrets/diffview.nvim', -- optional - Diff integration

            -- Only one of these is needed, not both.
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
        event = "InsertEnter",
        config = true
    }
}
