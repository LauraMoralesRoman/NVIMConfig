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

vim.api.nvim_create_user_command('ApplyAuraHighlightChanges', function()
    require 'highlight'
end, {
    desc = 'Apply the custom highlightings to fix the aura-theme'
})


-- returns Git repo root or fallback to current working directory
local function project_root()
    local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
    if vim.v.shell_error == 0 and git_root ~= "" then
        return git_root
    end
    return vim.loop.cwd()
end

vim.api.nvim_create_user_command('AstGrep', function()
    local root = project_root()

    local opts = {
        preview = string.format('bat --style=numbers --color=always --highlight-line {2} {1}'),
        fzf_opts = {
            ['--preview-window'] = 'right:60%',
            ['--delimeter'] = ':'
        },
        actions = {
            ['default'] = function(selected)
                -- selected[1] ~= "path/to/file:123:45: …"
                local path, line = selected[1]:match('([^:]+):(%d+):')
                if path and line then
                    vim.cmd(string.format('%s +%s', path, line))
                end
            end,
        },
        prompt = 'ast>',
        exec_empty_query = true,
        cwd = root
    }

    require 'fzf-lua'.fzf_live('ast-grep run --pattern <pattern> .', {
    }, opts)
end, {
    nargs = 0,
    desc  = "Live AST‑grep with proper CLI flags"
})

-- 3️⃣ Create a command to rename the current tab
vim.api.nvim_create_user_command('TabRename', function(opts)
    local new_name = opts.args
    -- Set tab-local variable 'TabName' on the **current** tab (0)
    vim.api.nvim_tabpage_set_var(0, 'TabName', new_name)
    -- Redraw the tabline so the change appears immediately
    vim.o.tabline = vim.o.tabline
end, {
    nargs = 1,
    desc = 'Rename the current tab'
})

-- Models I've tested:
-- llama3.1 for messages
-- nomic-embed-text:latest

local function run_job_quickfix(cmd, input, on_success)
    local stderr_buf = {}
    local stdout_buf = {}

    local job_id = vim.fn.jobstart(cmd, {
        stdin           = "pipe",
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout       = function(_, data)
            if data then
                for _, line in ipairs(data) do
                    if line ~= "" then table.insert(stdout_buf, line) end
                end
            end
        end,
        on_stderr       = function(_, data)
            if data then
                for _, line in ipairs(data) do
                    if line ~= "" then
                        table.insert(stderr_buf, line)
                    end
                end
            end
        end,
        on_exit         = vim.schedule_wrap(function(_, exit_code)
            if exit_code ~= 0 and #stderr_buf > 0 then
                -- build quickfix items
                local items = {}
                for _, line in ipairs(stderr_buf) do
                    table.insert(items, { text = line })
                end
                -- replace quickfix list and open it
                vim.fn.setqflist({}, "r", {
                    title = "Job Errors: " .. cmd[1],
                    items = items,
                })
                vim.cmd("copen")
            elseif exit_code == 0 and on_success then
                local out = table.concat(stdout_buf, '\n')
                on_success(out)
            end
        end),
    })

    vim.fn.chansend(job_id, input)
    vim.fn.chanclose(job_id, "stdin")
end


local function embed_selection(opts, generate_description)
    local bufnr                = vim.api.nvim_get_current_buf()
    local fullpath             = vim.api.nvim_buf_get_name(bufnr)
    local filename             = vim.fn.fnamemodify(fullpath, ":t")

    -- Determine visual or explicit range
    local start_line, end_line = nil, nil
    if opts.range then
        start_line, end_line = opts.line1, opts.line2
    else
        start_line = vim.fn.getpos("'<")[2]
        end_line   = vim.fn.getpos("'>")[2]
    end
    local range_str  = string.format("%d-%d", start_line, end_line)

    -- Generate UUID (requires uuidgen in PATH)
    local uuid       = vim.fn.system("uuidgen"):gsub("%s+", "")

    local key        = table.concat({ filename, range_str, uuid }, "_")
    local lines      = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
    local text       = table.concat(lines, "\n")
    local table_name = opts.args
    local filename   = vim.fn.expand('%:p')


    if generate_description then
        vim.notify("Generating metadata for " .. key, vim.log.levels.INFO)
        run_job_quickfix(
            { "llm", "-s", string.format('Generate a short description. For the file %s at the line %d',
                filename, start_line),
                "--schema",
                '{ "type": "object", "properties": { "description": { "type": "string" }, "filename": { "type": "string" }, "line": { "type": "number" } }, "required": ["description", "filename", "lines"], "additionalProperties": false }' },
            text,
            function(metadata)
                -- on metadata success, launch embedding job likewise
                print(metadata)
                run_job_quickfix(
                    { "llm", "embed", "--metadata", metadata, "--store", table_name, key },
                    text,
                    function(_)
                        vim.notify("Embedding saved: " .. key, vim.log.levels.INFO)
                    end
                )
            end
        )
    else
        local metadata = string.format('{"filename": "%s", "line": "%d"}', filename, start_line)
        run_job_quickfix(
            { "llm", "embed", '--metadata', metadata, "--store", table_name, key },
            text,
            function()
                vim.notify("Embedding saved: " .. key, vim.log.levels.INFO)
            end
        )
    end
end

vim.api.nvim_create_user_command(
    "Embed",
    function(opts)
        embed_selection(opts, false)
    end,
    {
        range = true, -- allow :<start>,<end>Embed
        nargs = 1,    -- require exactly one argument
        desc  = "Embed the given lines: llm embed --save <table> <key>",
    }
)

vim.api.nvim_create_user_command(
    "EmbedDescription",
    function(opts)
        embed_selection(opts, true)
    end,
    {
        range = true, -- allow :<start>,<end>Embed
        nargs = 1,    -- require exactly one argument
        desc  = "Embed the given lines: llm embed --save <table> <key>",
    }
)

local function llm_similar_to_qf(collection, query)
    -- 1. Run the external command, get each JSON line as a table entry
    local cmd = { "llm", "similar", collection, '-c', query }
    local lines = vim.fn.systemlist(cmd) -- :contentReference[oaicite:0]{index=0}

    -- 2. Handle errors
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_err_writeln("LLM similar failed:\n" .. table.concat(lines, "\n"))
        return
    end

    -- 3. Decode JSON lines into quickfix items
    local items = {}
    for _, line in ipairs(lines) do
        local ok, obj = pcall(vim.fn.json_decode, line)
        if ok and type(obj) == "table" then
            local file = (obj.metadata and obj.metadata.filename) or ""
            local lnum = (obj.metadata and obj.metadata.line) or 1
            local text = obj.content or ""
            local score = obj.score or 0
            local display = string.format('[%.5f] %s', score, text)
            table.insert(items, { filename = file, lnum = lnum, text = display })
        end
    end

    print(items)

    -- 4. Populate and open quickfix list
    vim.fn.setqflist({}, 'r', { title = ("Similar ‹%s›"):format(query), items = items })
    vim.cmd("copen")
end

function get_embed_projects()
    local out = vim.fn.system({ 'llm', 'collections', 'list', '--json' })

    local ok, obj = pcall(vim.fn.json_decode, out)

    local names = {}

    if ok then
        for _, item in ipairs(obj) do
            table.insert(names, item.name)
        end
        return names
    end

    return {}
end

-- Create a user command: :LLMSimilarQF <collection> <query...>
vim.api.nvim_create_user_command("FindEmbed", function(opts)
    -- Use opts.fargs to safely handle arguments
    local fargs = opts.fargs
    if #fargs < 2 then
        vim.api.nvim_err_writeln("Usage: FindEmbed <collection> <query>")
        return
    end
    local collection = fargs[1]
    -- Concatenate remaining args as query
    local query = table.concat({ unpack(fargs, 2) }, " ")
    llm_similar_to_qf(collection, query)
end, {
    nargs = "+",
    complete = function(arg_lead)
        return get_embed_projects()
    end,
})

vim.api.nvim_create_user_command('ListEmbeds', function()
    print('items')
    for _, item in ipairs(get_embed_projects()) do
        print(item)
    end
    -- run_job_quickfix({})
end, {
    nargs = 0
})

vim.api.nvim_create_user_command('DeleteEmbeds', function(opts)
    run_job_quickfix({ 'llm', 'collections', 'delete', opts.fargs[1] }, nil, function(_) end)
end, {
    nargs = 1,
    complete = function(arg_lead)
        return get_embed_projects()
    end
})
