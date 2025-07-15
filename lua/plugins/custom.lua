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
            { '<Leader><Leader>', '<cmd>FzfLua files<cr>',                 desc = 'Find files' },
            { '<Leader>,',        '<cmd>FzfLua buffers<cr>',               desc = 'Find buffers' },
            { '<Leader>/',        '<cmd>FzfLua live_grep<cr>',             desc = 'Search project' },
            { '<Leader>lw',       '<cmd>FzfLua lsp_workspace_symbols<cr>', desc = 'Search symbols in workspace' },
            { '<Leader>ls',       '<cmd>FzfLua lsp_document_symbols<cr>',  desc = 'Search symbols in document' },
            { '<Leader>lh',       '<cmd>LspClangdSwitchSourceHeader<cr>',  desc = 'Switch between source and header' },
            { '<Leader>lu',       '<cmd>FzfLua lsp_references<cr>',        desc = 'Search references to symbol' },
        },
        config = function()
            require 'fzf-lua'.setup {
                keymap = {
                    fzf = {
                        ['ctrl-q'] = 'select-all+accept',
                    },
                },
            }
        end
    },
    {
        'NeogitOrg/neogit',
        dependencies = {
            'nvim-lua/plenary.nvim',  -- required
            'sindrets/diffview.nvim', -- optional - Diff integration

            'ibhagwan/fzf-lua',       -- optional
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
    },
    {
        "stevearc/dressing.nvim",
        opts = {
            select = {
                -- put fzf_lua first so dressing.nvim picks it for vim.ui.select()
                backend = { "fzf_lua", "fzf", "builtin" },
                -- (optional) pass any fzf-lua-specific window opts here:
                fzf_lua = {
                    winopts = {
                        height = 0.4,
                        width  = 0.5,
                    },
                },
            },
        },
    },
    {
        "ziontee113/icon-picker.nvim",
        config = function()
            require("icon-picker").setup({ disable_legacy_commands = true })
        end,
        commands = {
            'IconPickerInsert',
            'IconPickerNormal',
            'IconPickerYank'
        }
    }
}
