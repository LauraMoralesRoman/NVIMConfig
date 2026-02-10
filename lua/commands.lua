local function close_hidden_buffers()
  local visible_buffers = {}
  
  -- Get all visible buffers from all windows in all tabs
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      local buf = vim.api.nvim_win_get_buf(win)
      visible_buffers[buf] = true
    end
  end
  
  -- Iterate through all buffers and delete the hidden ones
  local deleted_buffers = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and 
       vim.bo[buf].buflisted and 
       not visible_buffers[buf] then
      vim.api.nvim_buf_delete(buf, { force = false })
	  deleted_buffers = deleted_buffers + 1
    end
  end
  print("Deleted " .. deleted_buffers .. " buffers")
end

-- Create a command to call it
vim.api.nvim_create_user_command('CloseHiddenBuffers', close_hidden_buffers, {})
