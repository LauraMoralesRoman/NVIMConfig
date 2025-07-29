vim.api.nvim_create_autocmd('BufEnter', {
  pattern = '*',
  callback = function()
    local bt = vim.bo.filetype

    vim.cmd [[cnoreabbrev ollamaremote let $OLLAMA_HOST="192.168.1.3:11434"]]
    vim.cmd [[cnoreabbrev ollamalocal let $OLLAMA_HOST="127.0.0.1:11434"]]

    if bt == 'cpp' then
      vim.cmd [[iabbrev <buffer> tmpl template<typename ]]
    end
  end,
})
