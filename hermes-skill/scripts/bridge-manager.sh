#!/usr/bin/env bash
# bridge-manager.sh — Listener loop for Hermes Neovim Mode.
#
# Starts the bridge-listener.py in a continuous loop, forwarding
# received messages to a FIFO that the orchestrator reads.
#
# Usage:
#   bash bridge-manager.sh
#
# Signals:
#   sent to stdout:
#     BRIDGE_MANAGER_READY  (on successful start)
#   sent to FIFO:
#     JSON messages from the listener
#     {"type": "timeout"}        when listener times out
#     {"type": "error", ...}     on listener failures
#
# The orchestrator reads from the FIFO, processes messages, and
# kills this process (SIGTERM) to exit Neovim Mode.

SOCKET_PATH="${HERMES_BRIDGE_SOCKET:-/tmp/hermes-bridge-listener.sock}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LISTENER="$SCRIPT_DIR/bridge-listener.py"
FIFO="${HERMES_BRIDGE_FIFO:-/tmp/hermes-bridge-fifo}"
TIMEOUT="${HERMES_BRIDGE_TIMEOUT:-300}"

# Clean up on exit
cleanup() {
    rm -f "$FIFO" 2>/dev/null
    rm -f "$SOCKET_PATH" 2>/dev/null
}
trap cleanup EXIT SIGTERM SIGINT

# Clean any stale socket before starting
rm -f "$SOCKET_PATH" 2>/dev/null

# Create the FIFO for orchestrator communication
rm -f "$FIFO"
if ! mkfifo "$FIFO" 2>/dev/null; then
    echo "ERROR: Failed to create FIFO at $FIFO" >&2
    exit 1
fi

# Signal readiness (the orchestrator reads this from stdout)
echo "BRIDGE_MANAGER_READY"

while true; do
    # Run listener — it blocks until a message arrives or times out
    MSG=$("$LISTENER" "$SOCKET_PATH" --timeout "$TIMEOUT" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ] && [ -n "$MSG" ]; then
        # Message received successfully
        echo "$MSG" > "$FIFO"
    elif [ $EXIT_CODE -eq 1 ]; then
        # Timeout or empty — restart the loop
        echo '{"type":"timeout"}' > "$FIFO"
    else
        # Unexpected error
        # Escape the message for JSON
        ESCAPED=$(echo "$MSG" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null || echo '"unknown error"')
        echo "{\"type\":\"error\",\"message\":$ESCAPED}" > "$FIFO"
        # Brief pause before retrying to avoid tight error loops
        sleep 1
    fi
done