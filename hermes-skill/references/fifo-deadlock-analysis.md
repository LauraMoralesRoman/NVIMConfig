# FIFO Deadlock Analysis (nvim-bridge v1.0 → v2.0)

## The bug

v1.0's `bridge-manager.sh` looped:
1. Spawn `bridge-listener.py` (one-shot: creates socket, accepts one connection, exits)
2. `echo "$MSG" > /tmp/hermes-bridge-fifo` — write message to named FIFO
3. Restart listener
4. GOTO 1

## Why it deadlocks

Named FIFOs (created with `mkfifo`) have a fundamental constraint: **writes block until a reader opens the FIFO for reading**. If no process has the FIFO open for reading, `echo > FIFO` hangs forever.

The orchestrator (Hermes agent) cannot permanently block on reading the FIFO — it needs to process messages, spawn subagents, wait for `delegate_task` results, and send notifications. By the time it comes back to read the next message, the manager is already stuck on `echo > FIFO` for the previous message.

**Result:** Manager never restarts the listener → nvim gets `FileNotFoundError` (socket doesn't exist) → bridge permanently broken until restart.

## Why the FIFO was chosen (wrong assumption)

The assumption was that the orchestrator would block on `cat FIFO` in a loop, and that would be the orchestrator's main loop. But the orchestrator needs to do other work (DB ops, notifications, subagent spawning) between messages — it can't permanently block on a single FIFO read.

## The fix (v2.0)

Replace FIFO with a **filesystem queue**:

- `bridge-receiver.py`: persistent listener. Never exits. Each message becomes a numbered `.json` file in `/tmp/hermes-bridge-queue/`.
- `bridge-wait.py`: blocks via inotify (not polling). When a file appears, reads the oldest, prints to stdout, deletes it, exits.

The orchestrator calls `bridge-wait.py` as a foreground blocking process. When it returns (with a message), the orchestrator processes it, then immediately calls `bridge-wait.py` again. No deadlock possible — the receiver writes files independently of reader presence.

## Key insight

FIFOs are for streaming/pipe semantics. For message-passing between decoupled processes, use a filesystem queue or a persistent socket with reconnect. The filesystem queue has the additional benefit that messages survive orchestrator restarts.
