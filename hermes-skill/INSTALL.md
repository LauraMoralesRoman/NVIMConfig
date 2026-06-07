# Nvim-Bridge — Installation Guide for Another Hermes Agent

This directory contains everything needed to install the **nvim-bridge** — a two-way Neovim↔Hermes bridge over Unix sockets, with SQLite-backed task queueing and up to 3 concurrent `delegate_task` subagents.

## What's Here

```
hermes-skill/
├── INSTALL.md                          ← this file (instructions for the other agent)
├── SKILL.md                            ← the orchestrator skill (load this)
├── references/
│   ├── two-socket-diagnostic.md        ← troubleshooting the two sockets
│   └── fifo-deadlock-analysis.md       ← why v2 moved to filesystem queue
├── scripts/
│   ├── bridge-init.sh                  ← one-shot entry: socket check → DB init → receiver start → notify
│   ├── bridge-manager.sh               ← (legacy v1, not used by the skill)
│   ├── bridge-receiver.py              ← persistent Unix socket listener → JSON files in queue dir
│   ├── bridge-wait.py                  ← blocks via inotify, reads oldest, prints to stdout (~15ms wake)
│   ├── bridge-db.py                    ← SQLite CRUD + running_count + oldest_queued
│   └── bridge-listener.py              ← (legacy v1, one-shot listener)
└── lua/hermes-bridge/
    ├── init.lua                        ← Neovim plugin (:Hermes, :HermesCheckup, :HermesInit, safe_notify)
    ├── status-buffer.lua               ← :HermesCheckup status buffer with syntax highlighting
    └── notify.lua                      ← Optional: replaces vim.notify with coloured floating notifications
```

## Installation Steps

### 1. Copy the Scripts

Copy `scripts/*.py` and `scripts/bridge-init.sh` to the new agent's `~/.hermes/scripts/` directory:

```bash
# On the new agent's machine:
cp ~/.config/nvim/hermes-skill/scripts/bridge-init.sh   ~/.hermes/scripts/
cp ~/.config/nvim/hermes-skill/scripts/bridge-receiver.py ~/.hermes/scripts/
cp ~/.config/nvim/hermes-skill/scripts/bridge-wait.py    ~/.hermes/scripts/
cp ~/.config/nvim/hermes-skill/scripts/bridge-db.py      ~/.hermes/scripts/
cp ~/.config/nvim/hermes-skill/scripts/bridge-listener.py ~/.hermes/scripts/
cp ~/.config/nvim/hermes-skill/scripts/bridge-manager.sh  ~/.hermes/scripts/
chmod +x ~/.hermes/scripts/bridge-init.sh
```

> **Note:** `bridge-listener.py` and `bridge-manager.sh` are legacy v1. The current skill uses `bridge-receiver.py` + `bridge-wait.py` + `bridge-db.py`. They're included for reference only — you don't need to copy them unless you're debugging an old setup.

### 2. Install the Neovim Plugin

Copy `lua/hermes-bridge/` into your Neovim configuration:

```bash
# If your nvim config is at ~/.config/nvim/:
cp -r ~/.config/nvim/hermes-skill/lua/hermes-bridge ~/.config/nvim/lua/hermes-bridge
```

Then add it to your Neovim init:

```lua
-- In your init.lua or a plugin file (e.g. ~/.config/nvim/lua/plugins/basic.lua)
require("hermes-bridge")
```

This registers three user commands:

| Command | Purpose |
|---|---|
| `:Hermes <prompt>` | Sends a prompt/task to the Hermes orchestrator |
| `:HermesCheckup` | Opens a task status buffer in a new tab |
| `:HermesInit` | Starts the nvim-side listener socket (`/tmp/nvim-hermes-bridge.sock`) |

### 3. Add the Skill

Copy `SKILL.md` to the new agent's skills directory, or install it with the Hermes CLI:

```bash
# Option A: Copy directly
mkdir -p ~/.hermes/skills/software-development/nvim-bridge/
cp ~/.config/nvim/hermes-skill/SKILL.md ~/.hermes/skills/software-development/nvim-bridge/SKILL.md
cp ~/.config/nvim/hermes-skill/references/two-socket-diagnostic.md ~/.hermes/skills/software-development/nvim-bridge/references/
cp ~/.config/nvim/hermes-skill/references/fifo-deadlock-analysis.md ~/.hermes/skills/software-development/nvim-bridge/references/

# Option B: Use the skill tool (the agent can do this itself)
# skill_manage(action='create', name='nvim-bridge', content='...')
```

### 4. Start Neovim with the Listener

The nvim-side uses `nvim --listen /tmp/nvim-hermes-bridge.sock`. Either:

- Start nvim with: `nvim --listen /tmp/nvim-hermes-bridge.sock`
- Or inside nvim run: `:HermesInit` (which calls `vim.fn.serverstart('/tmp/nvim-hermes-bridge.sock')`)

## How It Works

```
nvim (lua/hermes-bridge/)                Hermes (the other agent)
┌──────────────────┐                 ┌──────────────────────────┐
│ sockconnect      │──── connect ───▶│ bridge-receiver.py       │
│   chansend JSON  │    /tmp/hermes- │   persistent listener    │
│   chanclose      │    bridge-      │   writes .json → queue   │
│                  │    listener.sock│                          │
│ :HermesCheckup   │                 │ bridge-db.py (SQLite)    │
│   ─▶ status tab  │                 │                          │
│                  │                 │ bridge-wait.py (blocks)  │
│ safe_notify ...  │◀── nvim         │   inotify wake-up ~15ms  │
│ _G.hermes.xxx    │    luaeval()    │                          │
└──────────────────┘    /tmp/nvim-   └──────────────────────────┘
                    hermes-bridge.sock
```

| Direction | Socket | How |
|---|---|---|
| **nvim → Hermes** | `/tmp/hermes-bridge-listener.sock` | `sockconnect("pipe", ...)` → send JSON → close |
| **Hermes → nvim** | `/tmp/nvim-hermes-bridge.sock` | `nvim --server <sock> --remote-expr "luaeval('...')"` |

## Key Concepts for the Orchestrator Agent

- **Orchestrator, not worker.** Every task is a `delegate_task()` subagent. The orchestrator only runs: `bridge-wait.py`, `bridge-db.py`, `bridge-init.sh`, `bridge-receiver.py`, and `nvim --remote-expr` notifications.
- **Max 3 concurrent subagents.** Up to 3 tasks run simultaneously. Additional tasks are queued in SQLite and promoted when a slot opens.
- **Init gate.** The orchestrator must run `bridge-init.sh` first. If the nvim socket doesn't exist, it exits 1 — hard stop, don't enter the loop.
- **Notifications use `luaeval()`.** Always `nvim --server /tmp/nvim-hermes-bridge.sock --remote-expr "luaeval('hermes.safe_notify(...)')"`. Never `--remote-send`. Always `terminal(background=true)` (fire-and-forget).
- **Exit cleanly.** Kill `bridge-receiver.py` (SIGTERM), cancel all non-completed tasks, clean up socket and queue.

## Dependencies

- **Neovim 0.10+** (for `sockconnect` with no third-arg quirk, `vim.fn.serverstart`)
- **Python 3** (scripts use stdlib only — no pip dependencies)
- **inotify** (Linux kernel feature for `bridge-wait.py`) — available on all modern Linux kernels