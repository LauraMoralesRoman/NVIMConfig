local function close_hidden_buffers(opts)
  local visible_buffers = {}

  -- collect all visible buffers
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      local buf = vim.api.nvim_win_get_buf(win)
      visible_buffers[buf] = true
    end
  end

  local deleted_buffers = 0
  local force = opts and opts.bang or false

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and not visible_buffers[buf] then
      -- skip modified buffers unless forced with !
      if force or not vim.bo[buf].modified then
        vim.api.nvim_buf_delete(buf, { force = force })
        deleted_buffers = deleted_buffers + 1
      end
    end
  end

  print('Deleted ' .. deleted_buffers .. ' buffers')
end

vim.api.nvim_create_user_command('CloseHiddenBuffers', close_hidden_buffers, { bang = true })

-- Set local (window) working directory to current buffer's directory
vim.api.nvim_create_user_command('Lhere', function()
  local dir = vim.fn.expand '%:p:h'
  vim.cmd('lcd ' .. dir)
end, { desc = 'Set local working directory to current buffer directory' })

-- Set tab working directory to current buffer's directory
vim.api.nvim_create_user_command('There', function()
  local dir = vim.fn.expand '%:p:h'
  vim.cmd('tcd ' .. dir)
end, { desc = 'Set tab working directory to current buffer directory' })

-- Set global working directory to current buffer's directory
vim.api.nvim_create_user_command('Here', function()
  local dir = vim.fn.expand '%:p:h'
  vim.cmd('cd ' .. dir)
end, { desc = 'Set global working directory to current buffer directory' })

-- Automatic qflist and loclist navigation

local qf_follow_enabled = false
local qf_follow_group = vim.api.nvim_create_augroup('QfFollow', { clear = true })

local qf_follow_ns = vim.api.nvim_create_namespace 'QfFollowHL'

local function qf_follow_attach()
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = qf_follow_group,
    buffer = 0,
    callback = function()
      local qf_win = vim.api.nvim_get_current_win()
      local info = vim.fn.getwininfo(qf_win)[1]
      if info.quickfix == 1 then
        if info.loclist == 1 then
          pcall(vim.cmd, ':.ll')
        else
          pcall(vim.cmd, ':.cc')
        end

        -- highlight the line in the source buffer
        local src_win = vim.api.nvim_get_current_win()
        local src_buf = vim.api.nvim_get_current_buf()
        local src_line = vim.api.nvim_win_get_cursor(src_win)[1] - 1 -- 0-indexed

        vim.cmd 'norm zz'

        vim.api.nvim_buf_clear_namespace(src_buf, qf_follow_ns, 0, -1)
        vim.api.nvim_buf_set_extmark(src_buf, qf_follow_ns, src_line, 0, {
          line_hl_group = 'CurSearch', -- swap for any highlight group you prefer
        })

        -- return focus to the qf/loc window
        vim.api.nvim_set_current_win(qf_win)
      end
    end,
  })
end

local function toggle_qf_follow()
  qf_follow_enabled = not qf_follow_enabled
  vim.api.nvim_clear_autocmds { group = qf_follow_group }

  if qf_follow_enabled then
    -- attach to qf/loc windows that are already open
    vim.api.nvim_create_autocmd('BufWinEnter', {
      group = qf_follow_group,
      pattern = 'quickfix',
      callback = qf_follow_attach,
    })
    -- also attach immediately if we're already inside a qf window
    local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
    if info and info.quickfix == 1 then
      qf_follow_attach()
    end
    vim.notify('QF follow: ON', vim.log.levels.INFO)
  else
    vim.notify('QF follow: OFF', vim.log.levels.INFO)
  end
end

vim.api.nvim_create_user_command('QfFollowEnable', function()
  qf_follow_enabled = true
  vim.api.nvim_clear_autocmds { group = qf_follow_group }

  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = qf_follow_group,
    pattern = 'quickfix',
    callback = qf_follow_attach,
  })

  local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
  if info and info.quickfix == 1 then
    qf_follow_attach()
  end

  vim.notify('QF follow: ON', vim.log.levels.INFO)
end, { desc = 'Enable quickfix/loclist cursor follow' })

vim.api.nvim_create_user_command('QfFollowDisable', function()
  qf_follow_enabled = false
  vim.api.nvim_clear_autocmds { group = qf_follow_group }
  vim.notify('QF follow: OFF', vim.log.levels.INFO)
end, { desc = 'Disable quickfix/loclist cursor follow' })

vim.api.nvim_create_user_command('QfFollowToggle', function()
  if qf_follow_enabled then
    vim.cmd 'QfFollowDisable'
  else
    vim.cmd 'QfFollowEnable'
  end
end, { desc = 'Toggle quickfix/loclist cursor follow' })
