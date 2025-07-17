-- ─────────────────────────────────────────────────────────────
-- Centered Intro Splash (standalone, no module)
-- ─────────────────────────────────────────────────────────────

-- Keep track of the floating window and buffer
local float_win, float_buf
local shown = false

-- Function to show the intro
local function show_centered_intro()
    if shown then
        return
    end

    shown        = true
    -- 1. Your intro text
    local lines  = {
        '',
        "     󰄛  CatNVIM  󰄛",
        " By Laura Morales Román ",
        '',
    }

    -- 2. Calculate width & height
    local lens   = vim.tbl_map(string.len, lines) -- map each line to its length
    local width  = math.max(unpack(lens))         -- unpack table into math.max
    local height = #lines

    -- 3. Determine center coordinates
    local tot_h  = vim.o.lines - vim.o.cmdheight -
        1        -- total editor rows minus command‑line :contentReference[oaicite:2]{index=2}
    local tot_w  = vim.o
        .columns -- total editor columns :contentReference[oaicite:3]{index=3}
    local row    = math.floor((tot_h - height) / 2)
    local col    = math.floor((tot_w - width) / 2)

    -- 4. Create a scratch buffer
    float_buf    = vim.api.nvim_create_buf(false, true) -- [listed=false, scratch=true] :contentReference[oaicite:4]{index=4}

    -- 5. Populate buffer with your lines
    vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, lines) -- (buf, start, end_, strict, lines) :contentReference[oaicite:5]{index=5}

    -- 6. Define a transparent highlight group
    vim.api.nvim_set_hl(0, "IntroFloat", { bg = "NONE" }) -- NONE makes background transparent

    -- 7. Open the floating window (focus remains in main window)
    float_win = vim.api.nvim_open_win(float_buf, false, {
        relative  = "editor",
        width     = width,
        height    = height,
        row       = row,
        col       = col,
        style     = "minimal",
        border    = "rounded",
        focusable = false
    }) -- leave enter/focus defaults :contentReference[oaicite:7]{index=7}

    -- 8. Apply per-window transparency & highlight
    vim.api.nvim_win_set_option(
        float_win,
        "winhighlight",
        "Normal:IntroFloat,FloatBorder:IntroFloat"
    ) -- override only this float’s highlights

    -- 9. Make buffer read‑only and auto‑wipe on close
    vim.api.nvim_buf_set_option(float_buf, "modifiable", false)
    vim.api.nvim_buf_set_option(float_buf, "bufhidden", "wipe")

    -- 🔟 Dismiss on any keypress
    local on_key_ns = vim.on_key(function(key)
        if float_win and vim.api.nvim_win_is_valid(float_win) then
            vim.api.nvim_win_close(float_win, true)
            float_win, float_buf = nil, nil
            vim.on_key(nil, on_key_ns) -- use ns_id here, not a table
            shown = false
        end
    end, nil, { expr = false })
end

-- Show only on clean startup (no files passed)
vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        if vim.fn.argc() == 0 then -- argc() == 0 means no file args :contentReference[oaicite:11]{index=11}
            show_centered_intro()
        end
    end,
})

-- Also close when a real file is read (name ≠ empty)
vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function()
        local name = vim.api.nvim_buf_get_name(0)
        if float_win and vim.api.nvim_win_is_valid(float_win)
            and name ~= "" then
            vim.api.nvim_win_close(float_win, true)
            float_win, float_buf = nil, nil
        end
    end,
})

-- Timer that resets on each user input
local idle_timer = vim.loop.new_timer()
local IDLE_TIME = 10000 -- milliseconds

-- Restarts the timer to fire after 5s of inactivity
local function reset_idle_timer()
    idle_timer:stop()
    idle_timer:start(IDLE_TIME, 0, vim.schedule_wrap(show_centered_intro))
end

-- Autocmds that reset the timer on user activity
vim.api.nvim_create_autocmd(
    { "CursorMoved", "CursorMovedI", "InsertEnter", "InsertLeave", "TextChanged", "TextChangedI" }, {
        callback = reset_idle_timer,
    })

-- Start timer initially
reset_idle_timer()

-- Don’t show the intro message on startup
vim.opt.shortmess:append("I")
