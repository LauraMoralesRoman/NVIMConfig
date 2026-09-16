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
vim.opt.equalalways = false

-- Formatting options
vim.opt_global.shiftwidth = 4
vim.opt_global.tabstop = 4
vim.opt_global.expandtab = false
vim.opt.wrap = false
vim.opt.breakindent = true
vim.opt.undofile = true

vim.opt.showcmd = true
vim.opt.showcmdloc = 'statusline'

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
  vim.g.neovide_no_window_decorations = false
  vim.keymap.set('n', '<F11>', function()
    vim.g.neovide_fullscreen = not vim.g.neovide_fullscreen
  end)
  vim.g.neovide_opacity = 0.8
end

vim.env.FZF_DEFAULT_COMMAND = 'rg --files --hidden --follow'

vim.api.nvim_set_hl(0, 'Pink', { fg = '#ff7be6', bold = true })
vim.api.nvim_set_hl(0, 'Gray', { fg = '#525252', italic = true })

-- Track session start time

-- Session time formatter - shows only the 2 most relevant units
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
_G.arglist_count = arglist_count
_G.arglist_fname = arglist_fname

_G.lsp_progress_safe = function()
  local ok, lsp_prog = pcall(require, 'lsp-progress')
  if ok then
    return lsp_prog.progress()
  end
  return ''
end

function _G.recording_status()
  local reg = vim.fn.reg_recording()
  if reg == '' then
    return ''
  end
  return '󰑖 @' .. reg
end

local pastel = {
  Normal = { bg = '#F5ABB9', fg = '#000000' }, -- soft lavender
  Insert = { bg = '#A8DCCB', fg = '#20382F' }, -- soft mint
  Visual = { bg = '#F3C98B', fg = '#40301F' }, -- soft peach
  Replace = { bg = '#E8A9B8', fg = '#402832' }, -- soft pink
  Command = { bg = '#A9C4E8', fg = '#253448' }, -- soft blue
  Terminal = { bg = '#9FD5E3', fg = '#24363D' }, -- soft cyan
}

local function set_statusline_colors()
  for mode, colors in pairs(pastel) do
    vim.api.nvim_set_hl(0, 'StatusLine' .. mode, {
      fg = colors.fg,
      bg = colors.bg,
      bold = true,
    })
  end

  vim.api.nvim_set_hl(0, 'StatusLineLaura', {
    fg = '#000000',
    bg = '#F5ABB9',
    bold = true,
  })
end

set_statusline_colors()

local mode_map = {
  n = { name = 'Normal', letter = 'N' },
  i = { name = 'Insert', letter = 'I' },
  v = { name = 'Visual', letter = 'V' },
  V = { name = 'Visual', letter = 'V' },
  ['\22'] = { name = 'Visual', letter = 'V' },
  R = { name = 'Replace', letter = 'R' },
  c = { name = 'Command', letter = 'C' },
  t = { name = 'Terminal', letter = 'T' },
  s = { name = 'Visual', letter = 'S' },
  S = { name = 'Visual', letter = 'S' },
}

function _G.my_statusline()
  local mode = mode_map[vim.fn.mode(1)] or mode_map.n
  local mode_hl = '%#StatusLine' .. mode.name .. '#'

  return table.concat({
    mode_hl,
    '  ' .. mode.letter .. '  ',
    '%#StatusLineLaura#  󰄛 Laura 󰄛 ',
    mode_hl,
    '  ',
    '%f',
    '%m',
    ' %{v:lua.arglist_count()}',
    ' %{v:lua.arglist_fname()}',
    '%=',
    '%S',
    '%{v:lua.recording_status()}',
    '%{v:lua.lsp_progress_safe()}',
    '%l:%c %p%%',
  }, ' ')
end

vim.opt.statusline = '%!v:lua.my_statusline()'

vim.api.nvim_create_autocmd('ModeChanged', {
  callback = function()
    vim.defer_fn(function()
      vim.cmd 'redrawstatus'
    end, 10)
  end,
})

vim.api.nvim_create_autocmd('ColorScheme', {
  callback = function()
    vim.defer_fn(set_statusline_colors, 10)
  end,
})

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
