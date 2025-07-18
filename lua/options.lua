-- Leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Basic options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = ''
vim.opt.cmdheight = 1

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.splitright = true
vim.opt.splitbelow = true

-- Formatting options
vim.opt_global.shiftwidth = 4
vim.opt_global.tabstop = 4
vim.opt_global.expandtab = true
vim.opt.wrap = false
vim.opt.breakindent = true
vim.opt.undofile = true

-- Graphical options
vim.g.have_nerd_font = true
vim.opt.signcolumn = 'yes'
vim.opt.updatetime = 250
vim.opt.list = true -- :help 'list' 'listchars'
vim.opt.listchars = {
    tab = '⇥ ',
    trail = '·',
    nbsp = '␣',
    extends = '',
    precedes = '',
}
vim.opt.inccommand = 'split'
vim.opt.cursorline = false
vim.opt.hlsearch = true
vim.opt.laststatus = 3

-- GUI options

if vim.g.neovide then
    vim.o.guifont = 'JetBrainsMono Nerd Font:h14'
    vim.g.neovide_scale_factor = 1.0
    vim.g.neovide_text_gamma = 0.9
    vim.g.neovide_text_contrast = 0.1
end

vim.env.FZF_DEFAULT_COMMAND = 'rg --files --hidden --follow'

vim.opt.statusline = table.concat({
    ' Laura 󰄛 ',
    '%f',                                          -- file path
    '%m',                                          -- modified flag
    '%=',                                          -- right-align
    '%{v:lua.require("lsp-progress").progress()}', -- ✨ LSP progress
    '%l:%c %p%%',                                  -- line:col and percent through file
}, ' ')

local signs = {
    { name = "DiagnosticSignError", text = "" },
    { name = "DiagnosticSignWarn", text = "" },
    { name = "DiagnosticSignInfo", text = "󰋼" },
    { name = "DiagnosticSignHint", text = "" },
}

for _, sign in ipairs(signs) do
    vim.fn.sign_define(sign.name, {
        texthl = sign.name,
        text   = sign.text,
        numhl  = ""
    })
end

vim.diagnostic.config({
    virtual_text = {
        prefix = function(diagnostic)
            local sev = diagnostic.severity
            if sev == vim.diagnostic.severity.ERROR then
                return " " -- Error icon
            elseif sev == vim.diagnostic.severity.WARN then
                return " " -- Warning icon
            elseif sev == vim.diagnostic.severity.INFO then
                return " " -- Info icon
            elseif sev == vim.diagnostic.severity.HINT then
                return " " -- Hint icon
            end
            return "" -- Fallback: no prefix
        end,
    }
})
