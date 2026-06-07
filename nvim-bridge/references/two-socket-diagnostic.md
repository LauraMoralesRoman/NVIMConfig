# Two-Socket Diagnostic Trap

The nvim-bridge uses two sockets with disjoint lifecycles:

| Socket | Owner | Used for | Alive when |
|---|---|---|---|
| `/tmp/nvim-hermes-bridge.sock` | nvim (`--listen`) | Hermes → nvim notifications | nvim is running |
| `/tmp/hermes-bridge-listener.sock` | bridge-listener.py | nvim → Hermes prompts | Neovim Mode active |

When `:Hermes <msg>` fails, either socket could be dead.

## Diagnostic flow (nvim-side Lua)

```lua
-- send_prompt tries to reach the listener socket first
if not M.send_to_listener(payload) then
  -- Check which socket is missing without leaking the channel
  local ok, ch = pcall(vim.fn.sockconnect, "pipe", "/tmp/nvim-hermes-bridge.sock")
  if ok then vim.fn.chanclose(ch) end
  if ok and ch > 0 then
    vim.notify("[Hermes] Not in Neovim Mode: tell Hermes 'start neovim mode'", ...)
  else
    vim.notify("[Hermes] No bridge socket: run :HermesInit then tell Hermes 'start neovim mode'", ...)
  end
end
```

## :HermesInit retry-on-stale

```lua
vim.api.nvim_create_user_command("HermesInit", function()
  local sock = "/tmp/nvim-hermes-bridge.sock"
  local ok, r = pcall(vim.fn.serverstart, sock)
  if ok and r and r ~= "" then
    -- success
  else
    -- Socket may be stale — try cleaning and retry once
    os.remove(sock)
    ok, r = pcall(vim.fn.serverstart, sock)
    if ok and r and r ~= "" then
      -- success after cleanup
    else
      -- unrecoverable error
    end
  end
end)
```

## Serverstart API quirk

`vim.fn.serverstart(path)` **throws** when the socket file already exists — it does NOT return 0 or a falsy value. Always wrap in `pcall`.

```lua
-- WRONG: throws instead of returning falsy
local r = vim.fn.serverstart(sock)
if r then ... end

-- CORRECT:
local ok, r = pcall(vim.fn.serverstart, sock)
if ok and r and r ~= "" then ... end
```