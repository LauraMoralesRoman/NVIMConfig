#!/usr/bin/env python3
"""bridge-receiver.py — Persistent socket listener for Hermes nvim-bridge.

Creates a Unix domain socket, accepts connections indefinitely, reads
JSON messages, and writes each one as a numbered file in a queue
directory. Runs continuously until killed.

Usage:
    bridge-receiver.py [socket_path] [queue_dir]

Default socket: /tmp/hermes-bridge-listener.sock
Default queue:  /tmp/hermes-bridge-queue
"""

import json
import os
import signal
import socket
import sys
import time

SOCKET_PATH = "/tmp/hermes-bridge-listener.sock"
QUEUE_DIR = "/tmp/hermes-bridge-queue"


def clean_stale_socket(sock_path):
    """Remove stale socket if not in use. Returns True if OK, False if in use."""
    if not os.path.exists(sock_path):
        return True
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    if s.connect_ex(sock_path) == 0:
        s.close()
        print(f"Socket {sock_path} already in use", file=sys.stderr)
        return False
    s.close()
    os.unlink(sock_path)
    return True


def recv_json(conn, timeout=30):
    """Receive all data from connection, parse as JSON."""
    conn.settimeout(timeout)
    data = b""
    try:
        while True:
            chunk = conn.recv(4096)
            if not chunk:
                break
            data += chunk
    except socket.timeout:
        pass

    if not data:
        return None

    text = data.decode("utf-8", errors="replace").strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return {"type": "raw", "data": text}


def ensure_queue_dir(queue_dir):
    """Create queue directory if it doesn't exist."""
    os.makedirs(queue_dir, exist_ok=True)


def write_to_queue(queue_dir, message):
    """Write message as numbered JSON file in queue directory.

    Uses millisecond timestamp + counter for unique ordering.
    Returns the filename written.
    """
    seq = int(time.time() * 1000)
    # Ensure uniqueness even with same-millisecond writes
    fname = os.path.join(queue_dir, f"{seq:016d}.json")
    counter = 0
    while os.path.exists(fname):
        counter += 1
        fname = os.path.join(queue_dir, f"{seq:016d}_{counter:04d}.json")
    with open(fname, "w") as f:
        json.dump(message, f)
    return fname


def main():
    sock_path = sys.argv[1] if len(sys.argv) > 1 else SOCKET_PATH
    queue_dir = sys.argv[2] if len(sys.argv) > 2 else QUEUE_DIR

    # Clean stale socket
    if not clean_stale_socket(sock_path):
        sys.exit(2)

    ensure_queue_dir(queue_dir)

    # Create and bind socket
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(sock_path)
    sock.listen(5)
    sock.settimeout(1.0)  # Periodic timeout so SIGTERM can interrupt accept
    os.chmod(sock_path, 0o600)

    # Flag to break the loop on SIGTERM
    running = True

    def handle_signal(signum, frame):
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    cleanup = True
    try:
        print(f"RECEIVER_READY {sock_path}", flush=True)
        while running:
            try:
                conn, addr = sock.accept()
            except socket.timeout:
                continue
            except OSError:
                # Socket closed during shutdown
                break

            msg = recv_json(conn)
            conn.close()

            if msg is not None:
                written = write_to_queue(queue_dir, msg)
                print(f"QUEUED {written}", flush=True)

    finally:
        sock.close()
        if cleanup:
            try:
                os.unlink(sock_path)
            except OSError:
                pass


if __name__ == "__main__":
    main()
