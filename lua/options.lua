-- Leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Basic options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = ''
vim.opt.cmdheight = 0

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.colorcolumn = '+1'
-- vim.opt.textwidth = 80

-- Formatting options
vim.opt_global.shiftwidth = 4
vim.opt_global.tabstop = 4
vim.opt_global.expandtab = false
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
vim.opt.cursorline = false
vim.opt.hlsearch = true
vim.opt.laststatus = 3
vim.opt.showtabline = 1

-- GUI options

if vim.g.neovide then
  vim.o.guifont = 'JetBrainsMono Nerd Font:h13'
  vim.g.neovide_scale_factor = 1.0
  vim.g.neovide_text_gamma = 0.9
  vim.g.neovide_text_contrast = 0.1
  vim.g.neovide_fullscreen = true
  vim.g.neovide_opacity = 0.8
end

vim.env.FZF_DEFAULT_COMMAND = 'rg --files --hidden --follow'

vim.api.nvim_set_hl(0, 'Pink', { fg = '#ff7be6', bold = true })
vim.api.nvim_set_hl(0, 'Gray', { fg = '#525252', italic = true })

-- Track session start time
vim.g.session_start = vim.fn.localtime()

-- Session time formatter - shows only the 2 most relevant units
local function session_time()
  local elapsed = vim.fn.localtime() - vim.g.session_start
  local hours = math.floor(elapsed / 3600)
  local minutes = math.floor((elapsed % 3600) / 60)
  local seconds = elapsed % 60

  if hours > 0 then
    return string.format('%dh %dm', hours, minutes)
  elseif minutes > 0 then
    return string.format('%dm %ds', minutes, seconds)
  else
    return string.format('%ds', seconds)
  end
end
-- Arglist filename - returns (filename) or empty
local function arglist_fname()
  local argc = vim.fn.argc()
  if argc == 0 then
    return ''
  end
  local fname = vim.fn.fnamemodify(vim.fn.argv(vim.fn.argidx()), ':t')
  return string.format('(%s)', fname)
end

-- Arglist count - returns [n/max] or empty
local function arglist_count()
  local argc = vim.fn.argc()
  if argc == 0 then
    return ''
  end
  local current = vim.fn.argidx() + 1
  return string.format('[%d/%d] ', current, argc)
end

-- Make it accessible from statusline
_G.session_time = session_time
_G.arglist_count = arglist_count
_G.arglist_fname = arglist_fname

_G.lsp_progress_safe = function()
  local ok, lsp_prog = pcall(require, 'lsp-progress')
  if ok then
    return lsp_prog.progress()
  end
  return ''
end

vim.opt.statusline = table.concat({
  '%#Pink# Laura 󰄛 ',
  '%#Normal# %f', -- file path
  '%m', -- modified flag
  ' %{v:lua.arglist_count()}', -- arglist counter [n/max]
  '%#Gray#%{v:lua.arglist_fname()}', -- (filename) in Gray/italic
  '%#Normal#', -- reset highlight
  '%{v:lua.hermes_task_status()}', -- Hermes task progress
  '%=', -- right-align rest
  '%{v:lua.lsp_progress_safe()}', -- LSP progress
  '%l:%c %p%%', -- line:col and percent
  '%#Gray# %{"[" . v:lua.session_time() . "] "}', -- ⏰ session time
}, ' ')

local timer = vim.loop.new_timer()
timer:start(
  0,
  1000,
  vim.schedule_wrap(function()
    vim.cmd 'redrawstatus'
  end)
)

local signs = {
  { name = 'DiagnosticSignError', text = '' },
  { name = 'DiagnosticSignWarn', text = '' },
  { name = 'DiagnosticSignInfo', text = '󰋼' },
  { name = 'DiagnosticSignHint', text = '' },
}

for _, sign in ipairs(signs) do
  vim.fn.sign_define(sign.name, {
    texthl = sign.name,
    text = sign.text,
    numhl = '',
  })
end

vim.diagnostic.config {
  virtual_text = {
    prefix = function(diagnostic)
      local sev = diagnostic.severity
      if sev == vim.diagnostic.severity.ERROR then
        return ' ' -- Error icon
      elseif sev == vim.diagnostic.severity.WARN then
        return ' ' -- Warning icon
      elseif sev == vim.diagnostic.severity.INFO then
        return ' ' -- Info icon
      elseif sev == vim.diagnostic.severity.HINT then
        return ' ' -- Hint icon
      end
      return '' -- Fallback: no prefix
    end,
  },
  signs = true,
  underline = true,
  update_in_insert = true, -- or false if you prefer, but this makes it obvious that updates are happening
  severity_sort = true,
}
