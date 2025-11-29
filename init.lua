prev_notify = vim.notify
vim.notify = function(msg, level, opts)
end

require 'options'
require 'keymaps'
require 'abbrev'
require 'centering'

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

require('lazy').setup {
  require 'plugins.basic',
  require 'plugins.code',
  require 'plugins.custom',
  require 'plugins.overhaul',
  require 'plugins.visual',
}

require 'autocmds'
require 'functions'

-- vim.cmd [[colorscheme lackluster-mint]]
vim.cmd [[colorscheme lackluster-hack]]
-- local config_path = vim.fn.stdpath("config")
-- vim.cmd('source ' .. config_path .. '/amber.vim')

require 'langs.godot'
require 'intro'

vim.notify = prev_notify
