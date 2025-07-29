require('lspconfig')['gdscript'].setup {
  name = 'godot',
  cmd = vim.lsp.rpc.connect('127.0.0.1', 6005),
}

vim.api.nvim_create_user_command('GodotStartServer', function()
  print 'Starting godot server'
  vim.fn.serverstart '/tmp/godot-server.pipe'
end, { nargs = 0 })
