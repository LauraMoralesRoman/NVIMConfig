-- ────────────────────────────────────────────────────────
-- Toggle Centered
-- ────────────────────────────────────────────────────────

-- state
local center_win, fake_buf, orig_buf

-- one‑off transparent highlight for the float
vim.api.nvim_set_hl(0, "FloatTransparent", { bg = "NONE" })

local function ToggleCenter()
    -- If the float is already open → close and restore
    if center_win and vim.api.nvim_win_is_valid(center_win) then
        vim.api.nvim_win_close(center_win, true)
        center_win = nil
        -- restore original buffer
        if orig_buf and vim.api.nvim_buf_is_valid(orig_buf) then
            vim.api.nvim_set_current_buf(orig_buf)
        end
        -- delete the underlying scratch
        if fake_buf and vim.api.nvim_buf_is_valid(fake_buf) then
            vim.api.nvim_buf_delete(fake_buf, { force = true })
        end
        fake_buf, orig_buf = nil, nil
        return
    end

    -- Save current buffer
    orig_buf   = vim.api.nvim_get_current_buf()

    -- Compute dimensions
    local cols = vim.o.columns
    local rows = vim.o.lines - vim.o.cmdheight - 1
    local tw   = (vim.o.textwidth > 0 and math.min(vim.o.textwidth, cols)) or math.min(80, cols)
    local w    = tw
    local h    = rows
    local row  = 0
    local col  = math.floor((cols - w) / 2)

    -- Create scratch underlay
    fake_buf   = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(fake_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(fake_buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_lines(fake_buf, 0, -1, false, { "" })
    vim.api.nvim_set_current_buf(fake_buf)

    -- Open floating window for original buffer
    center_win = vim.api.nvim_open_win(orig_buf, true, {
        relative = "editor",
        row      = row,
        col      = col,
        width    = w,
        height   = h,
        style    = "minimal",
        border   = "none",
    })

    -- Apply per-window highlight overrides
    vim.api.nvim_win_set_option(center_win, "winhighlight",
        "Normal:FloatTransparent,FloatBorder:FloatTransparent,Visual:Visual"
    )
end

-- Expose command and keymap
vim.api.nvim_create_user_command("ToggleCenter", ToggleCenter, {})
vim.keymap.set("n", "<leader>z", ":ToggleCenter<CR>", { desc = "Toggle centered &textwidth float" })
