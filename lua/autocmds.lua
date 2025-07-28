-- Make it so when you yank text a temporary highlight appears
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Helptags
-- 1. Capture the “default” runtimepath (as a list of paths)
local default_rtp

local M = {}
function M.update()
  vim.opt.runtimepath = default_rtp
  vim.opt.runtimepath:append(vim.loop.cwd())
  vim.cmd 'filetype detect'
end

-- Re-run on every directory change
vim.api.nvim_create_autocmd('DirChanged', {
  pattern = '*',
  callback = M.update,
})

vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    default_rtp = vim.split(vim.o.runtimepath, ',')
    M.update() -- see next section
  end,
})

vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '**/doc/*.txt',
  callback = function()
    vim.bo.filetype = 'help'
  end,
})

local doc_helptags = vim.api.nvim_create_augroup('DocHelptags', { clear = true })

vim.api.nvim_create_autocmd('BufWritePost', {
  group = doc_helptags,
  pattern = { '**/doc/**/*.txt', '**/doc/*.txt' },
  callback = function(ctx)
    -- 1️⃣ Find the top-level 'doc' directory for this file:
    local doc_root = vim.fn.finddir('doc', vim.fn.fnamemodify(ctx.file, ':p:h') .. ';')
    if doc_root == '' then
      return
    end

    -- 2️⃣ Generate tags there so :help can see them
    vim.cmd('silent! helptags ' .. vim.fn.fnameescape(doc_root))
  end,
})

-- Update the status bar when the LSP information changes
vim.api.nvim_create_autocmd('LspProgress', {
  callback = function()
    vim.cmd 'redrawstatus'
  end,
})

vim.api.nvim_set_hl(0, 'CursorWordHighlight', { bg = '#3e4452' }) -- choose any bg/fg you like :contentReference[oaicite:1]{index=1}

-- 2. Table to keep track of active match IDs
local cursor_word_matches = {}

-- 3. Create an autocmd group so we can clear it easily if needed
vim.api.nvim_create_augroup('CursorWordHighlight', { clear = true })

-- 4. On CursorHold (and when moving), highlight the word under cursor
vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorMoved' }, {
  group = 'CursorWordHighlight',
  callback = function()
    -- a) Clear any old matches
    for _, id in ipairs(cursor_word_matches) do
      pcall(vim.fn.matchdelete, id)
    end
    cursor_word_matches = {}

    -- b) Get the word under cursor
    local word = vim.fn.expand '<cword>'
    if word == '' then
      return
    end

    -- c) Build the exact‑word pattern
    local pat = '\\<' .. vim.fn.escape(word, '\\') .. '\\>'

    -- d) Add a new match with highest priority (10)
    local id = vim.fn.matchadd('CursorWordHighlight', pat, 10)
    table.insert(cursor_word_matches, id)
  end,
})

-- first, create your augroup
local group = vim.api.nvim_create_augroup('LocalInit', { clear = true })

vim.api.nvim_create_autocmd({ 'VimEnter', 'DirChanged' }, {
  group = group,
  callback = function()
    if vim.v.event.scope ~= 'global' then
      return
    end
    local cwd = vim.v.event.cwd

    for _, name in ipairs { 'init.vim', 'Session.vim' } do
      local path = cwd .. '/' .. name
      if vim.loop.fs_stat(path) then
        -- properly escape for Vim’s :source
        vim.schedule(function()
          vim.cmd('source ' .. vim.fn.fnameescape(path))
        end)
      end
    end

    -- …any additional logic…
  end,
  desc = 'Source local init.vim or Session.vim on VimEnter/DirChanged',
})
