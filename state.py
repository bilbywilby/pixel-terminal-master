#!/usr/bin/env python3
import sys
import sqlite3
import os
from datetime import datetime

DB_PATH = os.path.expanduser("~/.termux_master/state.db")

def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS runs (
            run_id INTEGER PRIMARY KEY AUTOINCREMENT,
            dag_id TEXT NOT NULL,
            status TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT,
            error_message TEXT
        )
    """)
    conn.commit()
    conn.close()

def record_start(dag_id):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    now = datetime.utcnow().isoformat() + "Z"
    cur.execute("INSERT INTO runs (dag_id, status, start_time) VALUES (?, 'running', ?)", (dag_id, now))
    run_id = cur.lastrowid
    conn.commit()
    conn.close()
    print(run_id)

def record_finish(run_id, status, error_msg=None):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    now = datetime.utcnow().isoformat() + "Z"
    cur.execute("UPDATE runs SET status = ?, end_time = ?, error_message = ? WHERE run_id = ?", 
                (status, now, error_msg, run_id))
    conn.commit()
    conn.close()

def list_runs(limit=5):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT run_id, dag_id, status, start_time, end_time, error_message FROM runs ORDER BY run_id DESC LIMIT ?", (limit,))
    rows = cur.fetchall()
    conn.close()
    
    if not rows:
        print("No run records found.")
        return

    print(f"{'ID':<5} {'DAG ID':<20} {'STATUS':<10} {'START TIME':<25} {'END TIME':<25}")
    print("-" * 85)
    for row in rows:
        r_id, dag, status, start, end, err = row
        print(f"{r_id:<5} {dag:<20} {status:<10} {start or '':<25} {end or '':<25}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(1)
    
    cmd = sys.argv[1]
    if cmd == "record-start" and len(sys.argv) >= 3:
        record_start(sys.argv[2])
    elif cmd == "record-finish" and len(sys.argv) >= 4:
        err = sys.argv[4] if len(sys.argv) > 4 else None
        record_finish(sys.argv[2], sys.argv[3], err)
    elif cmd == "list-runs":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 5
        list_runs(limit)
