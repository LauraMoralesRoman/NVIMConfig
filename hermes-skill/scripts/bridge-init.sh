#!/usr/bin/env bash
# bridge-init.sh — One-shot Neovim Mode initialization.
#
# Checks the nvim socket, cleans up, inits DB, starts the receiver,
# prints BRIDGE_READY, and EXITS. Does NOT hang — the receiver outlives
# this script. The orchestrator records the PID from stdout for cleanup.
#
# Usage: bash bridge-init.sh
#
# Exit codes:
#   0 — Everything started, BRIDGE_READY printed
#   1 — nvim socket not found (HARD STOP)
#   2 — Receiver failed to start

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECEIVER="$SCRIPT_DIR/bridge-receiver.py"
DB_SCRIPT="$SCRIPT_DIR/bridge-db.py"

NVIM_SOCK="/tmp/nvim-hermes-bridge.sock"
LISTENER_SOCK="/tmp/hermes-bridge-listener.sock"
QUEUE_DIR="/tmp/hermes-bridge-queue"

# ── STEP 1: Verify nvim socket ────────────────────────────────
if ! nvim --server "$NVIM_SOCK" --remote-expr '1+1' >/dev/null 2>&1; then
    echo "FATAL: Neovim bridge socket not found at $NVIM_SOCK" >&2
    echo ""
    echo "To use Neovim Mode, start nvim with:"
    echo "  nvim --listen /tmp/nvim-hermes-bridge.sock"
    echo ""
    echo "Or from inside an existing nvim session:"
    echo "  :echo vim.fn.serverstart('/tmp/nvim-hermes-bridge.sock')"
    echo ""
    echo 'Then say "start neovim mode" again.'
    exit 1
fi

# ── STEP 2: Clean stale artifacts ─────────────────────────────
rm -f "$LISTENER_SOCK" 2>/dev/null || true
rm -rf "$QUEUE_DIR" 2>/dev/null || true

# ── STEP 3: Initialize SQLite DB ──────────────────────────────
"$DB_SCRIPT" init >/dev/null

# ── STEP 4: Start bridge-receiver (disown it — outlives this script) ──
nohup python3 "$RECEIVER" "$LISTENER_SOCK" "$QUEUE_DIR" >/dev/null 2>&1 &
RECV_PID=$!

# Wait for receiver to create its socket
for _ in $(seq 1 50); do
    if [ -S "$LISTENER_SOCK" ]; then
        break
    fi
    sleep 0.05
done

if [ ! -S "$LISTENER_SOCK" ]; then
    echo "FATAL: bridge-receiver failed to start" >&2
    kill "$RECV_PID" 2>/dev/null || true
    exit 2
fi

# ── STEP 5: Notify nvim ──────────────────────────────────────
nvim --server "$NVIM_SOCK" --remote-expr "luaeval('hermes.safe_notify(\"Neovim Mode active\")')" 2>/dev/null || true

# ── Done — exit immediately, receiver lives on ────────────────
echo "BRIDGE_READY"
echo "RECEIVER_PID=$RECV_PID"
