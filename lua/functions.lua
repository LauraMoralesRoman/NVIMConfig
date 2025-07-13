vim.api.nvim_create_user_command('WipeWindowlessBufs', function()
    local bufinfos = vim.fn.getbufinfo { buflisted = true }
    vim.tbl_map(function(bufinfo)
        if bufinfo.changed == 0 and (not bufinfo.windows or #bufinfo.windows == 0) then
            print(('Deleting buffer %d : %s'):format(bufinfo.bufnr, bufinfo.name))
            vim.api.nvim_buf_delete(bufinfo.bufnr, { force = false, unload = false })
        end
    end, bufinfos)
end, { desc = 'Wipeout all buffers not shown in a window' })

vim.api.nvim_set_hl(0, 'HighlightedWindow', { bg = '#20093C' })
vim.api.nvim_create_user_command('HighlightWindow', function()
    -- what winhighlight is currently set to
    local current = vim.api.nvim_win_get_option(0, 'winhighlight')
    local hl_def = 'Normal:HighlightedWindow'

    if current == hl_def then
        -- already highlighted → clear back to default
        vim.api.nvim_win_set_option(0, 'winhighlight', '')
    else
        -- not highlighted → apply our group
        vim.api.nvim_win_set_option(0, 'winhighlight', hl_def)
    end
end, {
    nargs = 0,
    desc = 'Toggle highlight on the current window',
})

-- in your init.lua:
vim.api.nvim_create_user_command('ToggleEditorGuides', function()
    local enabled = vim.wo.colorcolumn ~= '80'

    if enabled then
        -- ── Enable guide + hard wrap ───────────────────────
        vim.wo.colorcolumn = '80' -- show ruler at col 80 :contentReference[oaicite:0]{index=0}
        vim.bo.textwidth = 80     -- auto-wrap at 80 chars :contentReference[oaicite:1]{index=1}
        vim.bo.formatoptions = vim.bo.formatoptions ..
            't'                   -- add 't' to auto-wrap as you type :contentReference[oaicite:2]{index=2}
    else
        -- ── Disable guide + hard wrap ────────────────────
        vim.wo.colorcolumn = ''                                   -- hide ruler :contentReference[oaicite:3]{index=3}
        vim.bo.textwidth = 0                                      -- turn off hard wrap :contentReference[oaicite:4]{index=4}
        vim.bo.formatoptions = vim.bo.formatoptions:gsub('t', '') -- remove 't' :contentReference[oaicite:5]{index=5}
    end
end, {
    desc = 'Toggle 80-col guide plus textwidth/formatoptions',
})
