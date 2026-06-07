#!/usr/bin/env python3
"""bridge-db.py — SQLite task database for Hermes nvim-bridge.

Usage:
  bridge-db.py init                    Create/reset schema
  bridge-db.py add <id> <desc>         Add a task
  bridge-db.py status <id> <status>    Update task status
  bridge-db.py log <id> <message>      Append log message
  bridge-db.py list [status]           List tasks (optional filter)
  bridge-db.py logs <id>               List log entries for a task
  bridge-db.py delete <id>             Delete task and its logs
  bridge-db.py stats                   Show summary statistics
  bridge-db.py running_count           Count of currently running tasks
  bridge-db.py oldest_queued           Get oldest queued task (or null)

Exit codes:
  0  Success
  1  Error (wrong args, DB error, etc.)
"""

import json
import os
import sqlite3
import sys

DB_PATH = os.environ.get("BRIDGE_DB_PATH", os.path.expanduser("~/.hermes/bridge-tasks.db"))
os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

SCHEMA = """
CREATE TABLE IF NOT EXISTS tasks (
    id          TEXT PRIMARY KEY,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    description TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'running', 'finishing', 'completed', 'cancelled')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS task_log (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id   TEXT NOT NULL,
    timestamp TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    message   TEXT NOT NULL,
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_task_log_task_id ON task_log(task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_created ON tasks(created_at DESC);
"""

VALID_STATUSES = {"queued", "running", "finishing", "completed", "cancelled"}


class Database:
    def __init__(self, db_path: str = DB_PATH):
        self.db_path = db_path
        self.conn: sqlite3.Connection | None = None

    def connect(self) -> sqlite3.Connection:
        if self.conn is None:
            self.conn = sqlite3.connect(self.db_path)
            self.conn.row_factory = sqlite3.Row
            self.conn.execute("PRAGMA journal_mode=WAL")
            self.conn.execute("PRAGMA foreign_keys=ON")
        return self.conn

    def close(self):
        if self.conn:
            self.conn.close()
            self.conn = None

    def init(self) -> str:
        conn = self.connect()
        conn.executescript(SCHEMA)
        conn.commit()
        return "OK"

    def add_task(self, task_id: str, description: str) -> str:
        conn = self.connect()
        conn.execute(
            "INSERT OR REPLACE INTO tasks (id, description) VALUES (?, ?)",
            (task_id, description),
        )
        conn.commit()
        return f"OK {task_id}"

    def set_status(self, task_id: str, status: str) -> str:
        if status not in VALID_STATUSES:
            return f"ERROR: invalid status '{status}'"
        conn = self.connect()
        cursor = conn.execute(
            "UPDATE tasks SET status = ?, updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?",
            (status, task_id),
        )
        conn.commit()
        if cursor.rowcount == 0:
            return f"ERROR: task '{task_id}' not found"
        return f"OK {task_id} -> {status}"

    def log_message(self, task_id: str, message: str) -> str:
        conn = self.connect()
        conn.execute(
            "INSERT INTO task_log (task_id, message) VALUES (?, ?)",
            (task_id, message),
        )
        conn.commit()
        return f"OK {task_id}"

    def list_tasks(self, status_filter: str | None = None) -> list[dict]:
        conn = self.connect()
        if status_filter:
            rows = conn.execute(
                "SELECT * FROM tasks WHERE status = ? ORDER BY created_at",
                (status_filter,),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM tasks ORDER BY CASE status "
                "WHEN 'running' THEN 0 "
                "WHEN 'finishing' THEN 1 "
                "WHEN 'queued' THEN 2 "
                "WHEN 'completed' THEN 3 "
                "WHEN 'cancelled' THEN 4 END, created_at DESC"
            ).fetchall()
        return [dict(r) for r in rows]

    def get_logs(self, task_id: str) -> list[dict]:
        conn = self.connect()
        rows = conn.execute(
            "SELECT * FROM task_log WHERE task_id = ? ORDER BY timestamp",
            (task_id,),
        ).fetchall()
        return [dict(r) for r in rows]

    def delete_task(self, task_id: str) -> str:
        conn = self.connect()
        cursor = conn.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
        conn.commit()
        if cursor.rowcount == 0:
            return f"ERROR: task '{task_id}' not found"
        return f"OK {task_id}"

    def stats(self) -> dict:
        conn = self.connect()
        rows = conn.execute(
            "SELECT status, COUNT(*) as count FROM tasks GROUP BY status"
        ).fetchall()
        total = conn.execute("SELECT COUNT(*) as c FROM tasks").fetchone()["c"]
        result = {r["status"]: r["count"] for r in rows}
        result["total"] = total
        return result

    def running_count(self) -> int:
        conn = self.connect()
        row = conn.execute(
            "SELECT COUNT(*) as c FROM tasks WHERE status = 'running'"
        ).fetchone()
        return row["c"]

    def oldest_queued(self) -> dict | None:
        conn = self.connect()
        row = conn.execute(
            "SELECT * FROM tasks WHERE status = 'queued' ORDER BY created_at LIMIT 1"
        ).fetchone()
        return dict(row) if row else None


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(1)

    cmd = args[0]
    db = Database()

    def need(n):
        if len(args) < n:
            print(f"{cmd} needs at least {n - 1} arguments", file=sys.stderr)
            sys.exit(1)

    try:
        if cmd == "init":
            print(db.init())

        elif cmd == "add":
            need(3)
            print(db.add_task(args[1], args[2]))

        elif cmd == "status":
            need(3)
            result = db.set_status(args[1], args[2])
            print(result)
            if result.startswith("ERROR"):
                sys.exit(1)

        elif cmd == "log":
            need(3)
            print(db.log_message(args[1], args[2]))

        elif cmd == "list":
            print(json.dumps(db.list_tasks(args[1] if len(args) > 1 else None)))

        elif cmd == "logs":
            need(2)
            print(json.dumps(db.get_logs(args[1])))

        elif cmd == "delete":
            need(2)
            result = db.delete_task(args[1])
            print(result)
            if result.startswith("ERROR"):
                sys.exit(1)

        elif cmd == "stats":
            print(json.dumps(db.stats()))

        elif cmd == "running_count":
            print(db.running_count())

        elif cmd == "oldest_queued":
            result = db.oldest_queued()
            print(json.dumps(result) if result else "null")

        else:
            print(f"Unknown command: {cmd}", file=sys.stderr)
            sys.exit(1)

    except sqlite3.Error as e:
        print(f"Database error: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    main()
