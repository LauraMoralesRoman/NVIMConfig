return {
  {
    'mozanunal/sllm.nvim',
    config = function()
      require('sllm').setup {
        -- llm_cmd = 'llm --system "Give the shortes answer possible while answering the question unless asked to elaborate. Never add code comments"',
        default_model = 'ministral-3:8b',
        window_type = 'right',
        pick_func = function(items, opts, on_choice)
          require('fzf-lua').fzf_exec(items, {
            prompt = opts.prompt,
            winopts = { height = 0.4, width = 0.6, row = 0.3, col = 0.5 },
            fzf_opts = { ['--layout'] = 'reverse-list' },
            actions = {
              -- map <CR> to call on_choice with the first selected item
              ['default'] = function(selected)
                -- selected is a table of chosen lines
                on_choice(selected[1], 1)
              end,
            },
          })
        end,
        notify_func = vim.notify,
        input_func = function(opts, on_confirm)
          -- opts.prompt is the message to show
          local answer = vim.fn.input((opts.prompt or '') .. ' ')
          on_confirm(answer)
        end,
      }
    end,
  },
}
