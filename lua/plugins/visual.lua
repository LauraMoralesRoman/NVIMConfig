-- ~/.config/nvim/lua/plugins/sidebar.lua

-- Helper to focus the sidebar and jump to a section by its title
local function jump_to_section(title)
  return function()
    require("sidebar-nvim").open()
    -- Find the sidebar window
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match("sidebar") or vim.bo[buf].filetype == "SidebarNvim" then
        vim.api.nvim_set_current_win(win)
        -- Search for the section title line
        vim.fn.search(title, "w")
        break
      end
    end
  end
end

return {
	{
		  "sidebar-nvim/sidebar.nvim",
		  config = function()
			require("sidebar-nvim").setup({
			  disable_default_keybindings = 0, -- keep 't' to toggle collapse, 'e' to open files, etc.
			  open = false,
			  side = "left",
			  initial_width = 35,
			  hide_statusline = false,
			  update_interval = 1000,

			  sections = { "diagnostics", "todos", "git", "buffers" },

			  section_separator     = { "", "──────────────────", "" },
			  section_title_separator = { "" },

			  bindings = {
				["q"] = function() require("sidebar-nvim").close() end,
			  },

			  -- All sections start collapsed; use 't' on their title to expand

			  ["diagnostics"] = {
				icon = "",
				initially_closed = true,
			  },

			  ["todos"] = {
				icon = "",
				ignored_paths = { "~" },
				initially_closed = true,
			  },

			  ["git"] = {
				icon = "",
				initially_closed = true,
			  },

			  ["buffers"] = {
				icon = "󰓩",
				sorting = "id",
				show_numbers = true,
				ignore_terminal = true,
				initially_closed = true,
			  },
			})
		  end,

		  cmd = {
			  'SidebarNvimToggle'
		  },

		  keys = {
			-- Sidebar open/close/focus
			{ "<leader>sb", "<cmd>SidebarNvimToggle<CR>",                 desc = "Sidebar: Toggle" },
			{ "<leader>sf", "<cmd>SidebarNvimFocus<CR>",                  desc = "Sidebar: Focus" },

			-- Jump directly to a section (opens sidebar + moves cursor to title)
			{ "<leader>s3", jump_to_section("Git"),                       desc = "Sidebar: Jump to Git" },
			{ "<leader>s1", jump_to_section("Diagnostics"),               desc = "Sidebar: Jump to Diagnostics" },
			{ "<leader>s2", jump_to_section("TODOs"),                     desc = "Sidebar: Jump to TODOs" },
			{ "<leader>s4", jump_to_section("Buffers"),                   desc = "Sidebar: Jump to Buffers" },
		  },

	}
}

