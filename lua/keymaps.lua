-- Movement
vim.keymap.set('n', 'j', 'gj')
vim.keymap.set('n', 'k', 'gk')

vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

vim.keymap.set('n', 'H', '<cmd>tabprevious<cr>', { desc = 'Move to the next tab' })
vim.keymap.set('n', 'L', '<cmd>tabnext<cr>', { desc = 'Move to the previous tab' })

-- Splits
vim.keymap.set('n', '|', '<cmd>vertical belowright split<cr>', { desc = 'Vertical split' })
vim.keymap.set('n', '\\', '<cmd>belowright split<cr>', { desc = 'Horizontal split' })

vim.keymap.set('n', '<C-M-k>', function()
    require('smart-splits').resize_up()
end, { desc = 'Resize split up', noremap = true, silent = true })
vim.keymap.set('n', '<C-M-j>', function()
    require('smart-splits').resize_down()
end, { desc = 'Resize split down', noremap = true, silent = true })
vim.keymap.set('n', '<C-M-h>', function()
    require('smart-splits').resize_left()
end, { desc = 'Resize split left', noremap = true, silent = true })
vim.keymap.set('n', '<C-M-l>', function()
    require('smart-splits').resize_right()
end, { desc = 'Resize split right', noremap = true, silent = true })

-- Diagnostics
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous [D]iagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next [D]iagnostic message' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- QOL
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('t', '<C-space>', '<C-\\><C-n>', { silent = true }) -- Exit terminal mode
vim.keymap.set('n', '<C-c>', '<Esc>')

-- Tools
vim.keymap.set('n', '<Leader>t', '<cmd>Lspsaga term_toggle<cr>')

-- LSP
vim.keymap.set('n', '<Leader>n', '<cmd>cnext<cr>')
vim.keymap.set('n', '<Leader>p', '<cmd>cprevious<cr>')

-- Show all symbols in the current buffer, listed in quickfix
vim.keymap.set('n', '<Leader>ls', function()
    vim.lsp.buf.document_symbol()
end, { desc = 'List document symbols' })

-- Use VIM bettwe, idiot
vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

local function open_in_tab_with_w3m()
    local url = vim.fn.expand('<cfile>') -- get URL/text under cursor
    vim.cmd(string.format('tabnew | terminal w3m %s', url))
end

vim.keymap.set(
    'n',  -- mode: normal
    'gx', -- key sequence
    open_in_tab_with_w3m,
    { noremap = true, silent = true }
)

-- DAP

vim.keymap.set('n', '<Leader>dc', function() require('dap').continue() end)
vim.keymap.set('n', '<Leader>dn', function() require('dap').step_over() end)
vim.keymap.set('n', '<Leader>di', function() require('dap').step_into() end)
vim.keymap.set('n', '<Leader>do', function() require('dap').step_out() end)  -- Shift+F11
vim.keymap.set('n', '<Leader>db', function() require('dap').toggle_breakpoint() end)
vim.keymap.set('n', '<Leader>dB', function() require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: ')) end)
vim.keymap.set('n', '<Leader>dr', function() require('dap').repl.open() end)
vim.keymap.set('n', '<Leader>dl', function() require('dap').run_last() end)
vim.keymap.set({'n', 'v'}, '<Leader>dh', function() require('dapui').eval() end)  -- Hover-like evaluation
