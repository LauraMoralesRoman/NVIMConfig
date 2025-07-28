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
vim.opt.cursorline = false
vim.opt.hlsearch = true
vim.opt.laststatus = 3

-- GUI options

if vim.g.neovide then
  vim.o.guifont = 'JetBrainsMono Nerd Font:h13'
  vim.g.neovide_scale_factor = 1.0
  vim.g.neovide_text_gamma = 0.9
  vim.g.neovide_text_contrast = 0.1
  vim.g.neovide_fullscreen = true
end

vim.env.FZF_DEFAULT_COMMAND = 'rg --files --hidden --follow'

vim.api.nvim_set_hl(0, 'Pink', { fg = '#ff7be6', bold = true })
vim.api.nvim_set_hl(0, 'Gray', { fg = '#525252', italic = true })

vim.opt.statusline = table.concat({
  '%#Pink# Laura 󰄛 ',
  '%#Normal# %f ', -- file path
  '%m', -- modified flag
  '%=', -- right-align rest
  '%{v:lua.require("lsp-progress").progress()}', -- LSP progress
  '%l:%c %p%%', -- line:col and percent
  '%#Gray# %{"[" . strftime("%H:%M:%S") . "]"}', -- ⏰ current time
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
}

function TabLine()
  local s = ''
  local cur = vim.fn.tabpagenr() -- current tab index :contentReference[oaicite:4]{index=4}
  local total = vim.fn.tabpagenr '$' -- total number of tabs :contentReference[oaicite:5]{index=5}
  for i = 1, total do
    -- highlight selected vs inactive
    s = s .. (i == cur and '%#TabLineSel#' or '%#TabLine#')
    -- make tabs clickable: %iT jumps to tab i
    s = s .. '%' .. i .. 'T '

    -- try to get a custom name
    local ok, name = pcall(vim.api.nvim_tabpage_get_var, i, 'TabName')
    if not ok or name == '' then
      -- fallback: use buffer filename tail
      local buflist = vim.fn.tabpagebuflist(i)
      local winnr = vim.fn.tabpagewinnr(i)
      local buf = buflist[winnr]
      -- vim.api.nvim_buf_get_name always expects a valid buffer handle
      local full = vim.api.nvim_buf_get_name(buf)
      name = vim.fn.fnamemodify(full, ':t') -- tail of path :contentReference[oaicite:7]{index=7}
      if name == '' then
        name = '[No Name]'
      end
    end

    s = s .. ' ' .. name .. ' '
  end
  -- fill remainder of line
  return s .. '%#TabLineFill#%T'
end

-- 2️⃣ Tell Neovim to use it
vim.o.tabline = '%!v:lua.TabLine()'
