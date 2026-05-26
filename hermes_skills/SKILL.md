---
name: hermes-neovim-bridge
description: "Neovim bridge: blocking wait script. Run ~/.hermes/scripts/nvim-mode-wait.sh, it blocks until new :Hermes messages arrive, then returns all queued JSON as stdout."
version: 5.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [neovim, nvim, bridge, hermes, remote, blocking, queue]
---

# Hermes Neovim Bridge (v5 — Blocking Wait)

## Architecture

  You (in nvim)                    Hermes (me)
       |                                    |
       | :Hermes "do X"                     |
       |----------------------------------->|  write ~/.hermes/nvim-msgs/TS.json
       |                                    |
       |                      [I run nvim-mode-wait.sh]
       |                                    |
       |                      [BLOCKED... waiting for files]
       |                                    |
       |                      [file appears!]
       |                      [script exits with JSON]
       |                                    |
       |                      [I process it, edit files]
       |                                    |
       |   [Hermes] Done with "do X"       |
       |<-----------------------------------|  nvim --server <sock> --remote-send
       |                                    |
       |                      [I run wait.sh again]
       |                                    |
       |                      [BLOCKED...]
       |                                    |
       | :Hermes "do Y"                     |
       |----------------------------------->|  write TS.json
       |                      [script exits...]
       |                                    |

  You (chat): "exit neovim mode"
       |----------------------------------->|  interrupts my wait.sh
       |                                    |
       |                      [I stop, normal chat resumes]

## Nvim side

File: `~/.config/nvim/lua/hermes_bridge/hermes.lua` (branch `hermes-bridge`)

`:Hermes <msg>` writes a queued file:
```bash
~/.hermes/nvim-msgs/20260526_112300.json
```

Format:
```json
{
  "message": "continue this config",
  "timestamp": "2026-05-26T11:23:00Z",
  "nvim_socket": "/tmp/nvim_hermes.sock",
  "cwd": "/home/laura/.config/nvim",
  "buffer": "init.lua"
}
```

## Hermes side

### Script: `~/.hermes/scripts/nvim-mode-wait.sh`

This script is the ONLY waiting mechanism.  It does ONE thing:

1. **Process all existing** `~/.hermes/nvim-msgs/*.json` immediately.
2. **If empty, BLOCK** until a new `.json` file appears (via `inotifywait`).
3. **When file(s) appear, exit** and print all JSON messages to stdout.
4. **Caller deletes files** after reading them.

```bash
bash ~/.hermes/scripts/nvim-mode-wait.sh
# (blocks here...)
# (exits when :Hermes is used, prints JSON lines)
```

### How neovim mode works (TESTED)

**Entry**: You say "enter neovim mode" or `:Hermes start mode`.

1. I spawn the script in a **background terminal**:
   ```bash
   terminal ~/.hermes/scripts/nvim-mode-wait.sh, background=True, notify_on_complete=True
   ```
2. The script **blocks** (zero CPU via `inotifywait`).  It is "stuck".
3. When you run `:Hermes <msg>`, nvim writes a file to `~/.hermes/nvim-msgs/`.
4. `inotifywait` detects the create event and the script **exits immediately**.
5. I get notified by the background process completion, receive the JSON stdout,
   process the messages, and notify back via `--remote-send`.
6. I **immediately re-run the script** in a new background terminal.
7. Loop continues.  I am "stuck" again, waiting for the next `:Hermes`.

**Exit**: You say "exit neovim mode".

1. I kill the background waiting process.
2. Normal chat resumes.

### No cron, no polling waste, no missed messages

The script uses `inotifywait` for zero-CPU sleep.  If `inotifywait` is not
available, it falls back to a 2-second poll loop.

## Status Updates During Long Tasks

When in neovim mode and processing a multi-step task, I push **transient
status updates** to your nvim command line every few seconds.  You see
progress without manual interaction:

```bash
# Lightweight, auto-disappears after next keypress
nvim --server /tmp/nvim_hermes.sock \
     --remote-send ':lua require("hermes_bridge.hermes").status("Step 2/5: parsing...")<CR>'
```

For critical milestones or completion, use the persistent popup:

```bash
# Stays on screen until dismissed (or auto-dismisses if using mini.notify)
nvim --server /tmp/nvim_hermes.sock \
     --remote-send ':lua require("hermes_bridge.hermes").notify("Done!")<CR>'
```

**Notification plugin:** `echasnovski/mini.notify` is configured in
`lua/plugins/notify.lua`.  It shows plain text bottom-right, no icons,
auto-dismisses after 3 seconds (5s for errors).  This replaces the default
`vim.notify` so all Hermes notifications use it.

**Rule of thumb:**
- `M.status()` for ongoing progress ("Parsing...", "Writing file...").
- `M.notify()` for final results or errors.

### Remote State Inspection

Hermes can query nvim state live via `--remote-expr` before acting:

```bash
# Full state snapshot (cwd, mode, buffer, all buffers, all tabs)
nvim --server /tmp/nvim_hermes.sock \
     --remote-expr 'luaeval("require(\"hermes_bridge.hermes\").state_json()")'
```

Returns JSON:
```json
{
  "cwd": "/home/laura/project",
  "mode": "n",
  "buffer": {
    "name": "/home/laura/project/src/main.lua",
    "number": 5,
    "line": 42,
    "col": 12
  },
  "buffers": [
    "/home/laura/project/src/main.lua",
    "/home/laura/project/README.md"
  ],
  "tabs": [
    { "windows": ["main.lua"] },
    { "windows": ["README.md", "terminal"] }
  ]
}
```

Quick shortcuts:
```bash
# Just buffer list
nvim --server /tmp/nvim_hermes.sock \
     --remote-expr 'luaeval("require(\"hermes_bridge.hermes\").buffers_json()")'

# Just cursor position + current file
nvim --server /tmp/nvim_hermes.sock \
     --remote-expr 'luaeval("require(\"hermes_bridge.hermes\").cursor_json()")'
```

**Note:** `--remote-expr` returns a Vim string.  Wrap in `luaeval()` to call
Lua functions that return JSON strings.  The result is a single JSON string
that Hermes parses with `jq` or Python `json.loads()`.

## Common Pitfalls

1. **`<CR>` in --remote-send must be literal.** The command string must end
   with `<CR>` or nvim won't execute it.
2. **Socket may be empty.** If `nvim_socket == ""`, use chat replies only.
3. **Delete after processing.** The script deletes files itself.
4. **Interrupt = exit.** The background process is killed to stop neovim mode.
5. **Output may be multiple JSON lines.** If rapid-fire `:Hermes` commands
   arrive while the script was not running, all queued files are returned at once.
