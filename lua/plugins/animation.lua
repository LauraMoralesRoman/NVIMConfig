return {
  {
    'nvim-mini/mini.animate',
    version = false,
    event = 'VeryLazy',

    opts = function()
      local animate = require 'mini.animate'

      return {
        -- Cursor movement
        cursor = {
          enable = true,
          timing = animate.gen_timing.linear {
            duration = 50,
            unit = 'total',
          },
          path = animate.gen_path.line {
            predicate = function()
              return true
            end,
          },
        },

        -- Smooth scrolling
        scroll = {
          enable = true,
          timing = animate.gen_timing.linear {
            duration = 70,
            unit = 'total',
          },
          subscroll = animate.gen_subscroll.equal {
            max_output_steps = 8,
          },
        },

        -- Window resizing
        resize = {
          enable = true,
          timing = animate.gen_timing.linear {
            duration = 70,
            unit = 'total',
          },
        },
      }
    end,
  },
}
