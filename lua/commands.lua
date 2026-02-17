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
    if vim.api.nvim_buf_is_valid(buf)
      and vim.bo[buf].buflisted
      and not visible_buffers[buf]
    then
      -- skip modified buffers unless forced with !
      if force or not vim.bo[buf].modified then
        vim.api.nvim_buf_delete(buf, { force = force })
        deleted_buffers = deleted_buffers + 1
      end
    end
  end

  print("Deleted " .. deleted_buffers .. " buffers")
end

vim.api.nvim_create_user_command(
  'CloseHiddenBuffers',
  close_hidden_buffers,
  { bang = true }
)

-- Set local (window) working directory to current buffer's directory
vim.api.nvim_create_user_command('Lhere', function()
  local dir = vim.fn.expand('%:p:h')
  vim.cmd('lcd ' .. dir)
end, { desc = 'Set local working directory to current buffer directory' })

-- Set tab working directory to current buffer's directory
vim.api.nvim_create_user_command('There', function()
  local dir = vim.fn.expand('%:p:h')
  vim.cmd('tcd ' .. dir)
end, { desc = 'Set tab working directory to current buffer directory' })

-- Set global working directory to current buffer's directory
vim.api.nvim_create_user_command('Here', function()
  local dir = vim.fn.expand('%:p:h')
  vim.cmd('cd ' .. dir)
end, { desc = 'Set global working directory to current buffer directory' })
