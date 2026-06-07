#!/usr/bin/env python3
"""bridge-wait.py — Block until a message appears in the queue directory.

Uses inotify for instant wake when a file is created (no polling delay).
Reads the oldest queued message file, prints it to stdout, deletes the
file, and exits. Blocks indefinitely until a message arrives.

Usage:
    bridge-wait.py [queue_dir]

Default queue dir: /tmp/hermes-bridge-queue

Exit codes:
    0 — Message printed to stdout
    1 — Timeout or error
"""

import ctypes
import ctypes.util
import errno
import json
import os
import select
import struct
import sys

QUEUE_DIR = "/tmp/hermes-bridge-queue"

# ── inotify bindings ──────────────────────────────────────────

_libc = None

def _load_libc():
    global _libc
    if _libc is None:
        lib_path = ctypes.util.find_library("c")
        _libc = ctypes.CDLL(lib_path, use_errno=True)
    return _libc

def inotify_init():
    libc = _load_libc()
    IN_NONBLOCK = 0o4000  # linux/fcntl.h
    fd = libc.inotify_init1(IN_NONBLOCK)
    if fd < 0:
        raise OSError(ctypes.get_errno(), "inotify_init1 failed")
    return fd

def inotify_add_watch(fd, path, mask):
    libc = _load_libc()
    path_bytes = path.encode("utf-8") + b"\x00"
    wd = libc.inotify_add_watch(fd, path_bytes, ctypes.c_uint32(mask))
    if wd < 0:
        raise OSError(ctypes.get_errno(), f"inotify_add_watch failed for {path}")
    return wd

# Event masks
IN_CLOSE_WRITE = 0x00000008
IN_MOVED_TO    = 0x00000080
IN_CREATE      = 0x00000100
IN_DELETE      = 0x00000200
IN_ONLYDIR     = 0x01000000

WATCH_MASK = IN_CLOSE_WRITE | IN_MOVED_TO | IN_CREATE

# inotify_event struct: wd, mask, cookie, len, name (variable)
_EVENT_FMT = "iIII"
_EVENT_SIZE = struct.calcsize(_EVENT_FMT)


def read_event(fd):
    """Read one inotify event. Returns (wd, mask, cookie, name) or None on EAGAIN."""
    try:
        data = os.read(fd, 4096)
    except BlockingIOError:
        return None
    if not data:
        return None
    wd, mask, cookie, name_len = struct.unpack_from(_EVENT_FMT, data)
    name = data[_EVENT_SIZE:_EVENT_SIZE + name_len].rstrip(b"\x00").decode("utf-8", errors="replace")
    return wd, mask, cookie, name


def get_oldest_message(queue_dir):
    """Return (filename, data) of oldest message, or (None, None)."""
    try:
        files = sorted(os.listdir(queue_dir))
    except FileNotFoundError:
        return None, None

    for fname in files:
        if not fname.endswith(".json"):
            continue
        fpath = os.path.join(queue_dir, fname)
        try:
            with open(fpath, "r") as f:
                data = json.load(f)
            return fpath, json.dumps(data)
        except (json.JSONDecodeError, OSError):
            try:
                os.unlink(fpath)
            except OSError:
                pass
    return None, None


def main():
    queue_dir = sys.argv[1] if len(sys.argv) > 1 else QUEUE_DIR
    os.makedirs(queue_dir, exist_ok=True)

    # Check if there's already a message waiting (avoid unnecessary inotify setup)
    fpath, data = get_oldest_message(queue_dir)
    if fpath is not None:
        print(data, flush=True)
        try:
            os.unlink(fpath)
        except OSError:
            pass
        sys.exit(0)

    # Set up inotify watch on the queue directory
    try:
        ifd = inotify_init()
        inotify_add_watch(ifd, queue_dir, WATCH_MASK)
    except OSError as e:
        # Fall back to polling if inotify fails
        import time
        while True:
            fpath, data = get_oldest_message(queue_dir)
            if fpath is not None:
                print(data, flush=True)
                try:
                    os.unlink(fpath)
                except OSError:
                    pass
                sys.exit(0)
            time.sleep(0.1)

    # Block on inotify events
    try:
        while True:
            # select with 60s timeout as safety net (catches missed events)
            r, _, _ = select.select([ifd], [], [], 5.0 * 60.0)
            if not r:
                # Timeout — check if a message arrived anyway
                fpath, data = get_oldest_message(queue_dir)
                if fpath is not None:
                    print(data, flush=True)
                    try:
                        os.unlink(fpath)
                    except OSError:
                        pass
                    break
                continue

            # Drain all pending events
            while True:
                event = read_event(ifd)
                if event is None:
                    break

            # After events, check for messages
            fpath, data = get_oldest_message(queue_dir)
            if fpath is not None:
                print(data, flush=True)
                try:
                    os.unlink(fpath)
                except OSError:
                    pass
                break
    finally:
        os.close(ifd)


if __name__ == "__main__":
    main()
