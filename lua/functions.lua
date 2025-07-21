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

local inlay_hints_enabled = true
vim.api.nvim_create_user_command('ToggleInlayHints', function()
    inlay_hints_enabled = not inlay_hints_enabled
    vim.lsp.inlay_hint.enable(inlay_hints_enabled)
end, { nargs = 0 })

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

local function llm_similar_to_qf(collection)
    local data = {} -- will hold id → parsed object

    require("fzf-lua").fzf_live(
    -- fn(query) : called on every keystroke (subject to debounce)
        function(query)
            -- 1. run your external LLM command
            local cmd   = { "llm", "similar", collection, "-c", query }
            local lines = vim.fn.systemlist(cmd)

            if vim.v.shell_error ~= 0 then
                -- return a single-item list with the error
                return { "⚠ LLM similar failed:\n" .. table.concat(lines, "\n") }
            end

            -- 2. parse JSON lines and collect IDs
            data = {}
            local ids = {}
            for _, line in ipairs(lines) do
                local ok, obj = pcall(vim.fn.json_decode, line)
                if ok and type(obj) == "table" and obj.id then
                    data[obj.id] = obj
                    table.insert(ids, obj.id)
                end
            end

            return ids
        end,
        {
            prompt           = string.format("Similar (%s)> ", collection),
            exec_empty_query = false, -- run even when query is empty
            debounce_delay   = 1000,  -- wait 200 ms after last keypress

            -- Preview the selected ID by pulling from `data`
            preview          = function(entry)
                local obj = data[entry[1]]
                if not obj then
                    return "No preview available"
                end
                local md    = obj.metadata or {}
                local file  = md.filename or "[no file]"
                local ln    = md.line or 1
                local score = obj.score or 0
                local txt   = obj.content or ""
                return string.format(
                    "[%s:%d]\n SCORE: %.5f\n\n%s",
                    file, ln, score, txt
                )
            end,

            -- Layout and sizing
            winopts          = {
                height = 0.7,
                width  = 0.6,
                row    = 0.3,
                col    = 0.5,
            },

            fzf_opts         = {
                ["--layout"] = "reverse-list",
                -- optionally bind <C-p> to toggle preview:
                ["--preview-window"] = "right:60%",
            },

            -- On <Enter>, open the file at the specified line
            actions          = {
                default = function(selected)
                    local obj = data[selected[1]]
                    if obj and obj.metadata and obj.metadata.filename then
                        local f = obj.metadata.filename
                        local l = obj.metadata.line or 1
                        vim.cmd(string.format("edit +%d %s", l, f))
                    end
                end,
            },
        }
    )
end

-- Usage:
-- :lua llm_similar_to_qf("my-collection")

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
    local collection = fargs[1]
    -- Concatenate remaining args as query
    llm_similar_to_qf(collection)
end, {
    nargs = 1,
    complete = function(arg_lead)
        return get_embed_projects()
    end,
})

vim.api.nvim_create_user_command('ListEmbeds', function()
    for _, item in ipairs(get_embed_projects()) do
        print(item)
    end
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

vim.api.nvim_create_user_command('DeleteEmbeddingEntry', function(opts)
    local db = vim.fn.systemlist({ 'llm', 'collections', 'path' })[1] -- Fucking newline
    print('Removing from ' .. db)

    local collection = opts.fargs[1]
    local query =
        string.format(
            'SELECT embeddings.id, content FROM embeddings JOIN collections ON collection_id = collections.id WHERE collections.name = \'%s\'',
            collection)
    local out = vim.fn.system({ 'sqlite3', db, '.mode json', query })
    local ok, obj = pcall(vim.fn.json_decode, out)

    if not ok then
        print('Failed to get information: ', out)
    end

    local items = {}

    for _, item in ipairs(obj) do
        table.insert(items, item.id)
    end

    local previews = {}

    for _, item in ipairs(obj) do
        previews[item.id] = item.content
    end

    require("fzf-lua").fzf_exec(items, {
        preview  = function(entry, line_nr, _fzf_opts)
            return previews[entry[1]] or 'not found'
        end,
        prompt   = 'Select id to delete',
        winopts  = { height = 0.7, width = 0.6, row = 0.3, col = 0.5 },
        fzf_opts = {
            ["--layout"] = "reverse-list",
        },
        actions  = {
            ["default"] = function(selected)
                local query = string.format('DELETE FROM embeddings WHERE id = \'%s\'', selected[1])
                local out = vim.fn.system({ 'sqlite3', db, query })
                print(out)
            end,
        },
    })
end, {
    nargs = 1,
    complete = function(arg_lead)
        return get_embed_projects()
    end
})
