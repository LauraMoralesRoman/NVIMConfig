---
name: nvim-bridge
description: "Two-way Neovim bridge via Unix sockets. Max 3 concurrent delegate_task subagents with SQLite-backed queueing. Persistent socket receiver + filesystem queue."
version: 2.3.0
tags: [neovim, nvim, bridge, socket, orchestrator, concurrent, queue]
---

# Nvim Bridge — Orchestrator Skill

## CRITICAL: You are an orchestrator, NOT a worker

**Your ONLY jobs:** receive messages from nvim, manage the SQLite database, spawn `delegate_task` subagents, send notifications to nvim. **You do NOT execute tasks yourself.** Every `:Hermes` task is delegated.

**If you call `terminal(...)`, `read_file(...)`, `write_file(...)`, or `patch(...)` to do a task's actual work, STOP. That is the subagent's job.**

## Architecture

```
nvim (lua/hermes-bridge/)                Hermes (this agent)
┌──────────────────┐                 ┌──────────────────────────┐
│ sockconnect      │──── connect ───▶│ bridge-receiver.py       │
│   chansend JSON  │    /tmp/hermes-  │   persistent listener    │
│   chanclose      │    bridge-       │   writes .json → queue   │
│                  │    listener.sock │                          │
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

Queue: `bridge-receiver.py` runs persistently. Messages → numbered JSON files in `/tmp/hermes-bridge-queue/`. `bridge-wait.py` uses inotify to wake within ~15ms.

## Neovim Mode — Entry

When the user says "start neovim mode":

### Step 1: Run the init script IN FOREGROUND

```
terminal("bash ~/.hermes/scripts/bridge-init.sh")
```

This is a foreground command. It blocks until the receiver is running. **Do NOT use background=true.** You MUST wait for it to complete.

### Step 2: Gate check — STOP IF IT FAILED

When the script returns, check both:
- **Exit code must be 0** — if non-zero, the nvim socket was not found. Do NOT proceed.
- **Stdout must contain `BRIDGE_READY`** — if missing, something went wrong.

```
IF exit_code != 0 OR stdout does not contain "BRIDGE_READY":
    ⤷ Report to user: "Neovim bridge socket not found. Start nvim with --listen /tmp/nvim-hermes-bridge.sock"
    ⤷ HARD STOP. Do NOT enter the loop. Do NOT start any background processes.
    ⤷ Do NOT retry.
```

### Step 3: Enter the orchestrator LOOP

Only if the gate passed. The init script's receiver is running. Start the loop.

### What the init script does (so you understand, but you just run it)

1. Tests `nvim --server /tmp/nvim-hermes-bridge.sock --remote-expr '1+1'` — if this fails, prints "FATAL" to stderr and exits 1 immediately. Nothing else happens.
2. Cleans stale sockets and queue dirs from previous sessions.
3. Initializes SQLite DB.
4. Starts `bridge-receiver.py` as a child process.
5. Sends "Neovim Mode active" to nvim.

## Orchestrator LOOP

Run this loop continuously. Each iteration processes exactly one message, then blocks on the next.

```
LOOP:

  ╔═══════════ STEP 1: WAIT FOR MESSAGE ═══════════╗
  ║ terminal("python3 ~/.hermes/scripts/bridge-wait.py /tmp/hermes-bridge-queue", timeout=600)
  ║ ⤷ stdout: one JSON message. ~15ms wake latency.
  ╚════════════════════════════════════════════════╝

  ╔═══════════ STEP 2: NOTIFY RECEIPT (background, fire-and-forget) ═══════════╗
  ║ terminal(bg=true, command="""
  ║   nvim --server /tmp/nvim-hermes-bridge.sock --remote-expr "luaeval('hermes.safe_notify(\"Received: <truncated text>\")')"
  ║ """)
  ╚════════════════════════════════════════════════════════════════════════════╝

  ╔═══════════ STEP 3: DISPATCH ═══════════╗

  ┌─ type: "cancel" ────────────────────────────────────────┐
  │ terminal("""                                              │
  │   python3 ~/.hermes/scripts/bridge-db.py log <id> "Cancelled by user" &&
  │   python3 ~/.hermes/scripts/bridge-db.py status <id> cancelled &&
  │   python3 ~/.hermes/scripts/bridge-db.py running_count
  │ """)                                                      │
  │ notify("Task <id> cancelled", WARN)                       │
  │ ⤷ If running_count < 3: PROMOTE (see below)              │
  │ ⤷ GOTO LOOP                                              │
  └───────────────────────────────────────────────────────────┘

  ┌─ type: "prompt", text contains "status"/"check"/"tasks" ──┐
  │ terminal("python3 ~/.hermes/scripts/bridge-db.py list")   │
  │ ⤷ Send results as notifications. GOTO LOOP.              │
  └───────────────────────────────────────────────────────────┘

  ┌─ type: "prompt", text is "exit"/"stop" ───────────────────┐
  │ ⤷ GOTO EXIT ROUTINE (kill receiver, cancel tasks)        │
  └───────────────────────────────────────────────────────────┘

  ┌─ type: "prompt" → NEW TASK ───────────────────────────────┐
  │ terminal("""                                              │
  │   python3 ~/.hermes/scripts/bridge-db.py add <uuid> "<desc>" &&
  │   python3 ~/.hermes/scripts/bridge-db.py running_count
  │ """)                                                      │
  │                                                           │
  │ IF running_count < 3:                                     │
  │   terminal("python3 ~/.hermes/scripts/bridge-db.py status <uuid> running")
  │   notify("Task spawned: <desc>")                          │
  │   delegate_task(goal="<prompt>", context="...", ...)      │
  │   ⤷ GOTO LOOP (subagent runs async)                      │
  │                                                           │
  │ IF running_count >= 3:                                    │
  │   terminal("python3 ~/.hermes/scripts/bridge-db.py status <uuid> queued")
  │   notify("Task queued (slot full): <desc>", WARN)         │
  │   ⤷ GOTO LOOP                                            │
  └───────────────────────────────────────────────────────────┘

  PROMOTE (after a task finishes or is cancelled):
    terminal("python3 ~/.hermes/scripts/bridge-db.py oldest_queued")
    ⤷ If not "null":
        terminal("python3 ~/.hermes/scripts/bridge-db.py status <id> running")
        notify("Promoted queued task: <desc>")
        delegate_task(goal="<desc>", context="...", ...)

  SUBAGENT RETURN (when delegate_task result arrives):
    terminal("python3 ~/.hermes/scripts/bridge-db.py status <uuid> finishing")
    terminal("python3 ~/.hermes/scripts/bridge-db.py log <uuid> <summary>")
    notify("Task complete: <summary>")
    terminal("python3 ~/.hermes/scripts/bridge-db.py status <uuid> completed")
    ⤷ PROMOTE
```

## Notification format — the ONLY syntax you use

```bash
nvim --server /tmp/nvim-hermes-bridge.sock --remote-expr "luaeval('hermes.safe_notify(\"your message\")')"
nvim --server /tmp/nvim-hermes-bridge.sock --remote-expr "luaeval('hermes.safe_notify(\"your message\", vim.log.levels.WARN)')"
nvim --server /tmp/nvim-hermes-bridge.sock --remote-expr "luaeval('hermes.safe_notify(\"your message\", vim.log.levels.ERROR)')"
```

**Always use `terminal(background=true, ...)` for notifications.** Never block on them.

**Quoting pattern:** outer `"..."` for shell, inner `'...'` for luaeval, escaped `\"...\"` for Lua strings.

## Spawning subagents

**Every task MUST use `delegate_task()`. Never execute a task yourself.**

```python
delegate_task(
    goal="<the user's exact prompt text>",
    context="""
TASK ID: <uuid>
NVIM SOCKET: /tmp/nvim-hermes-bridge.sock

EDITOR CONTEXT:
  Current file: <current_file>
  Working directory: <cwd>
  Active buffers: <active_buffers>
  Selected range: <range if present>

You are a subagent working on a task from Neovim.
Send progress updates directly to the editor:

  nvim --server /tmp/nvim-hermes-bridge.sock --remote-expr "luaeval('hermes.safe_notify(\"step done\")')"
  nvim --server /tmp/nvim-hermes-bridge.sock --remote-expr "luaeval('hermes.safe_notify(\"warning\", vim.log.levels.WARN)')"
  nvim --server /tmp/nvim-hermes-bridge.sock --remote-expr "luaeval('hermes.safe_notify(\"error\", vim.log.levels.ERROR)')"
  nvim --server /tmp/nvim-hermes-bridge.sock --remote-expr "luaeval('hermes.set_task(\"name\", 1, 3)')"
  nvim --server /tmp/nvim-hermes-bridge.sock --remote-expr "luaeval('hermes.update_task(2, 3)')"
  nvim --server /tmp/nvim-hermes-bridge.sock --remote-expr "luaeval('hermes.clear_task()')"
  nvim --server /tmp/nvim-hermes-bridge.sock --remote-expr "luaeval('vim.cmd(\"checktime\")')"

REQUIREMENTS:
- Notify on EVERY significant step. Use set_task/update_task/clear_task for statusline.
- Send ONE final summary notification when complete.
- safe_notify() queues if user is typing.
""",
    toolsets=["terminal", "file", "web", "search"],
)
```

**After calling `delegate_task()`, immediately GOTO LOOP.** Subagents run async.

## Notification events table

| Event | Notify (all INFO unless noted, all via `terminal(bg=true)`) |
|---|---|
| Neovim Mode active | `"Neovim Mode active"` |
| Message received | `"Received: <truncated text>"` |
| Task spawned | `"Task spawned: <desc>"` |
| Task queued | `"Task queued (slot full): <desc>"` (WARN) |
| Task cancelled | `"Task <id> cancelled"` (WARN) |
| Task complete | `"Task complete: <summary>"` |
| Task promoted | `"Promoted: <desc>"` |
| Task failed | `"Task <id> failed"` (ERROR) |
| Neovim Mode exited | `"Neovim Mode exited"` (WARN) |

## Exit

1. Kill `bridge-receiver.py` (SIGTERM).
2. Mark non-completed tasks as cancelled.
3. Notify nvim if socket alive.
4. Clean up: `rm -f /tmp/hermes-bridge-listener.sock && rm -rf /tmp/hermes-bridge-queue`

## Scripts

| Script | Purpose |
|---|---|
| `bridge-init.sh` | One-shot entry: socket check → DB init → receiver start → notify. Exits 1 if no nvim socket. |
| `bridge-receiver.py` | Persistent Unix socket listener → JSON files in queue dir |
| `bridge-wait.py` | Blocks via inotify, reads oldest, prints to stdout (~15ms wake) |
| `bridge-db.py` | SQLite CRUD + `running_count` + `oldest_queued` |

## Pitfalls

### CRITICAL: init script gate check

`bridge-init.sh` exits 1 if no nvim socket. **You MUST check the exit code.** If exit_code != 0 or stdout doesn't contain `BRIDGE_READY`: HARD STOP. Do not enter the loop. Do not background anything. Tell the user to start nvim with `--listen /tmp/nvim-hermes-bridge.sock`.

### CRITICAL: orchestrator vs worker

Every task is a `delegate_task` subagent. Orchestrator `terminal()` calls are limited to: `bridge-wait.py`, `bridge-db.py`, `nvim --remote-expr`, `bridge-init.sh`, `bridge-receiver.py` lifecycle.

### Notification syntax: `luaeval`, not `execute('lua ...')`

```bash
# CORRECT:
nvim --server ... --remote-expr "luaeval('hermes.safe_notify(\"hello\")')"

# WRONG:
nvim --server ... --remote-expr "execute('lua ...')"
nvim --server ... --remote-expr 'lua ...'
```

### `--remote-send` is FORBIDDEN

`--remote-send` injects text into the active buffer. Always use `--remote-expr "luaeval('...')"`.

### Notifications: fire-and-forget

Always `terminal(background=true, ...)` for notifications. Never block on them.

### DB batching

Combine with `&&`:
```bash
python3 bridge-db.py add <id> "<desc>" && python3 bridge-db.py running_count
```

### Inotify wake-up

`bridge-wait.py` uses `inotify_init1(IN_NONBLOCK)`. Wakes within ~15ms of file creation.

### Entry: single script, foreground only

Entry is ONE `terminal("bash bridge-init.sh")` — foreground, not background. Check exit code.
