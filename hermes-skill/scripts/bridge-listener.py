#!/usr/bin/env python3
"""bridge-listener.py — One-shot Unix socket message receiver.

Creates a Unix domain socket, accepts EXACTLY ONE connection, reads one
JSON message (line-delimited), prints it to stdout, and exits.

This is designed for the Hermes bridge where the orchestrator restarts
this process after each message, creating a continuous listener loop.

Usage:
    bridge-listener.py [socket_path] [--timeout SECONDS]

Default socket: /tmp/hermes-bridge-listener.sock
Default timeout: 300 seconds (5 minutes). Pass 0 for no timeout.

Returns:
    Exit 0: Message received, printed as JSON to stdout.
    Exit 1: Timeout (no connection received).
    Exit 2: Socket error (bind failed, address in use, etc.).
"""

import json
import os
import socket
import sys

SOCKET_PATH = "/tmp/hermes-bridge-listener.sock"
TIMEOUT = 300

def parse_args():
  args = sys.argv[1:]
  sock_path = SOCKET_PATH
  timeout = TIMEOUT
  i = 0
  while i < len(args):
    if args[i] == "--timeout" and i + 1 < len(args):
      timeout = int(args[i + 1]); i += 2
    elif args[i].startswith("--timeout="):
      timeout = int(args[i].split("=", 1)[1]); i += 1
    elif args[i].startswith("--"):
      print(f"Unknown option: {args[i]}", file=sys.stderr); sys.exit(2)
    else:
      sock_path = args[i]; i += 1
  return sock_path, timeout

def create_socket(sock_path):
  if os.path.exists(sock_path):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    is_live = s.connect_ex(sock_path) == 0
    s.close()
    if is_live:
      print(f"Socket {sock_path} in use", file=sys.stderr); sys.exit(2)
    os.unlink(sock_path)
  sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
  sock.bind(sock_path)
  sock.listen(1)
  sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
  os.chmod(sock_path, 0o600)
  return sock

def recv_all(conn):
  data = b""
  while True:
    chunk = conn.recv(4096)
    if not chunk: break
    data += chunk
  return data

def clean_exit(sock, sock_path, code):
  sock.close()
  if os.path.exists(sock_path): os.unlink(sock_path)
  sys.exit(code)

def main():
  sock_path, timeout = parse_args()
  sock = create_socket(sock_path)
  sock.settimeout(timeout if timeout > 0 else None)
  try:
    conn, _ = sock.accept()
  except socket.timeout:
    clean_exit(sock, sock_path, 1)
  except KeyboardInterrupt:
    clean_exit(sock, sock_path, 1)
  conn.settimeout(30)
  try:
    data = recv_all(conn)
  except socket.timeout:
    data = b""
  finally:
    conn.close()
    sock.close()
    if os.path.exists(sock_path): os.unlink(sock_path)
  if data:
    text = data.decode("utf-8", errors="replace").strip()
    try:
      print(json.dumps(json.loads(text)))
    except json.JSONDecodeError:
      print(json.dumps({"type": "raw", "data": text}))
    sys.exit(0)
  else:
    print(json.dumps({"type": "empty"}), file=sys.stderr)
    sys.exit(1)

if __name__ == "__main__":
  main()