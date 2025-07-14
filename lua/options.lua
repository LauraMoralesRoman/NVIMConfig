print 'options'
-- Leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Basic options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = ''

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.splitright = true
vim.opt.splitbelow = true

-- Formatting options
vim.opt_global.shiftwidth = 4
vim.opt_global.tabstop = 4
vim.opt_global.expandtab = true
-- vim.opt_global.wrap = false
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

-- GUI options

if vim.g.neovide then
    vim.o.guifont = 'JetBrainsMono Nerd Font:h14'
    vim.g.neovide_scale_factor = 1.0
    vim.g.neovide_text_gamma = 0.9
    vim.g.neovide_text_contrast = 0.1
end

vim.env.FZF_DEFAULT_COMMAND = 'rg --files --hidden --follow'

vim.opt.statusline = table.concat({
    'Laura Morales 󰄛 ',
    '%f',                                          -- file path
    '%m',                                          -- modified flag
    '%=',                                          -- right-align
    '%{v:lua.require("lsp-progress").progress()}', -- ✨ LSP progress
    '%l:%c %p%%',                                  -- line:col and percent through file
}, ' ')
