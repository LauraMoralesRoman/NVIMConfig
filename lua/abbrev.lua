vim.api.nvim_create_autocmd('BufEnter', {
    pattern = '*',
    callback = function()
        local bt = vim.bo.filetype

        if bt == 'cpp' then
            vim.cmd [[iabbrev <buffer> tmpl template<typename ]]
        end
    end
})
