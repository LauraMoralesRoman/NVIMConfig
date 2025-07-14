-- ────────────────────────────────────────────────────────
-- Toggle Centered &textwidth Float, Single‑Buffer Mode
-- ────────────────────────────────────────────────────────

-- state
local center_win, fake_buf, orig_buf

-- one‑off transparent highlight for the float
vim.api.nvim_set_hl(0, "FloatTransparent", { bg = "NONE" })

local function ToggleCenter()
    -- If the float is already open → close and restore
    if center_win and vim.api.nvim_win_is_valid(center_win) then
        -- close the floating window
        vim.api.nvim_win_close(center_win, true)
        center_win = nil
        -- switch back to the original buffer
        if orig_buf and vim.api.nvim_buf_is_valid(orig_buf) then
            vim.api.nvim_set_current_buf(orig_buf)
        end
        -- delete the fake underlying buffer
        if fake_buf and vim.api.nvim_buf_is_valid(fake_buf) then
            vim.api.nvim_buf_delete(fake_buf, { force = true })
        end
        fake_buf, orig_buf = nil, nil
        return
    end

    -- Otherwise: open centered float mode

    -- 1️⃣ Save the buffer you were editing
    orig_buf = vim.api.nvim_get_current_buf()

    -- 2️⃣ Create & switch to a blank scratch buffer underneath
    fake_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(fake_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(fake_buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_lines(fake_buf, 0, -1, false, { "" })
    vim.api.nvim_set_current_buf(fake_buf)

    -- 3️⃣ Compute float dimensions
    local ew   = vim.o.columns
    local eh   = vim.o.lines - vim.o.cmdheight - 1
    local tw   = vim.o.textwidth > 0 and math.min(vim.o.textwidth, ew) or math.min(80, ew)
    local w    = tw
    local h    = eh
    local row  = 0
    local col  = math.floor((ew - w) / 2)

    -- 4️⃣ Open the floating window editing your original buffer
    center_win = vim.api.nvim_open_win(orig_buf, true, {
        relative = "editor",
        row      = row,
        col      = col,
        width    = w,
        height   = h,
        style    = "minimal",
        border   = "none",
    })

    -- 5️⃣ Make only this float transparent
    vim.api.nvim_win_set_option(center_win, "winblend", 100)
    vim.api.nvim_win_set_option(
        center_win,
        "winhighlight",
        "Normal:FloatTransparent,FloatBorder:FloatTransparent"
    )
end

-- Expose a command and keymap
vim.api.nvim_create_user_command("ToggleCenter", ToggleCenter, {})
vim.keymap.set("n", "<leader>z", ":ToggleCenter<CR>", { desc = "Toggle centered &textwidth float" })
