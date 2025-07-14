return {
    {
        'hrsh7th/nvim-cmp',
        event = 'InsertEnter',
        dependencies = {
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-path',
        },
        config = function()
            local cmp = require 'cmp'

            cmp.setup {
                completion = {
                    completeopt = 'menu,menuone,noinsert',
                    autocomplete = false,
                },

                mapping = cmp.mapping.preset.insert {
                    ['<C-n>'] = cmp.mapping.select_next_item(),
                    ['<C-p>'] = cmp.mapping.select_prev_item(),
                    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-f>'] = cmp.mapping.scroll_docs(4),
                    ['<CR>'] = cmp.mapping.confirm { select = true },
                    ['<C-Space>'] = cmp.mapping.complete {},
                },
                sources = {
                    { name = 'nvim_lsp' },
                    { name = 'luasnip' },
                    { name = 'path' },
                },
            }
        end,
    },
    {
        'neovim/nvim-lspconfig',
        dependencies = {
            -- Automatically install LSPs and related tools to stdpath for Neovim
            { 'williamboman/mason.nvim', config = true }, -- NOTE: Must be loaded before dependants
            'williamboman/mason-lspconfig.nvim',
            'WhoIsSethDaniel/mason-tool-installer.nvim',

            -- Useful status updates for LSP. (bottom updates)
            -- { 'j-hui/fidget.nvim', opts = {} },
        },
        config = function()
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

            require('mason').setup()
            require('mason-lspconfig').setup {
                handlers = {
                    function(server_name)
                        local server = {}
                        server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
                        require('lspconfig')[server_name].setup(server)
                    end,
                },
            }
        end,
    },
    {
        'nvim-treesitter/nvim-treesitter',
        opts = {
            highlight = {
                enable = true,
            },
            indent = { enable = true },
        },
        config = function()
            require('nvim-treesitter.install').prefer_git = true

            vim.api.nvim_create_autocmd('BufEnter', {
                pattern = '*',
                callback = function()
                    vim.cmd 'TSBufEnable highlight'
                end,
            })
        end,
    },
    {
        'stevearc/conform.nvim',
        lazy = false,
        opts = {
            notify_on_error = false,
            format_on_save = function(bufnr)
                -- Disable "format_on_save lsp_fallback" for languages that don't
                -- have a well standardized coding style. You can add additional
                -- languages here or re-enable it for the disabled ones.
                local disable_filetypes = { zig = true }
                return {
                    timeout_ms = 500,
                    lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
                }
            end,
        },
    },
    {
        'nvimdev/lspsaga.nvim',
        lazy = false,
        config = function()
            require('lspsaga').setup {
                ui = {
                    code_action = '󰌵',
                },
                symbol_in_winbar = {
                    enable = false
                }
            }
        end,
        dependencies = {
            'nvim-treesitter/nvim-treesitter', -- optional
            'nvim-tree/nvim-web-devicons',     -- optional
        },
        keys = {
            {
                '<leader>lr',
                mode = 'n',
                '<cmd>Lspsaga rename<cr>',
            },
            {
                '<leader>la',
                mode = 'n',
                '<cmd>Lspsaga code_action<cr>',
            },
        },
    },
    {
        'linrongbin16/lsp-progress.nvim',
        config = function()
            require('lsp-progress').setup()
        end
    }
}
