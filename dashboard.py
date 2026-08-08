from __future__ import annotations

import hmac
import os
import subprocess
from pathlib import Path

from flask import Flask, jsonify, request, session, send_from_directory

import state

STATIC_DIR = Path(__file__).resolve().parent

import secrets

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY") or secrets.token_hex(32)

STORAGE_DIR = Path(os.environ.get("MASTER_STORAGE", str(Path.home() / ".termux_master")))
DAGS_DIR = STORAGE_DIR / "dags"
SCRIPTS_DIR = STORAGE_DIR / "scripts"
MASTER_BIN = os.environ.get("MASTER_BIN", str(STORAGE_DIR / "bin" / "master.sh"))
DASHBOARD_TOKEN = os.environ.get("TM_DASHBOARD_TOKEN", "").strip()


def _token_valid() -> bool:
    if not DASHBOARD_TOKEN:
        return True
    return hmac.compare_digest(request.headers.get("X-TM-Token", ""), DASHBOARD_TOKEN)


@app.before_request
def _authenticate():
    if request.path.startswith("/api/") and not _token_valid():
        return jsonify({"error": "unauthorized"}), 401


def init_storage() -> None:
    """Ensure baseline application directories and database are initialized."""
    STORAGE_DIR.mkdir(parents=True, exist_ok=True)
    DAGS_DIR.mkdir(parents=True, exist_ok=True)
    SCRIPTS_DIR.mkdir(parents=True, exist_ok=True)
    state.init_db()


def _safe_name(name: str, base_dir: Path) -> str:
    """Resolve and validate that the requested file remains inside base_dir."""
    target_path = (base_dir / name).resolve()
    if not str(target_path).startswith(str(base_dir.resolve())):
        raise ValueError("Directory traversal detected")
    return str(target_path)


@app.route("/")
def index():
    # Serves index.html placed next to dashboard.py. Not auth-gated (the
    # page itself is static HTML/JS; it's the /api/* calls it makes that
    # are protected by TM_DASHBOARD_TOKEN + CSRF).
    return send_from_directory(str(STATIC_DIR), "index.html")


@app.route("/api/csrf-token", methods=["GET"])
def get_csrf_token():
    if "csrf_token" not in session:
        session["csrf_token"] = secrets.token_hex(16)
    return jsonify({"csrf_token": session["csrf_token"]})


@app.route("/api/dags", methods=["GET"])
def list_dags():
    # DTO-centric (Option A): scripts/ is the single source of truth for
    # what's runnable. dags/ is reserved for future multi-step DAG graph
    # files and is intentionally NOT consulted here — see the incident
    # where dags/hello.sh existed but only scripts/hello.json executed.
    init_storage()
    if not SCRIPTS_DIR.exists():
        return jsonify([])
    ids = [f.stem for f in SCRIPTS_DIR.iterdir() if f.is_file() and f.suffix == ".json"]
    return jsonify(sorted(ids))


@app.route("/api/dags/<dag_id>/run", methods=["POST"])
def run_dag_endpoint(dag_id: str):
    # CSRF verification
    expected_csrf = session.get("csrf_token", "")
    provided_csrf = request.headers.get("X-TM-CSRF", "")
    if not expected_csrf or not hmac.compare_digest(provided_csrf, expected_csrf):
        return jsonify({"error": "Invalid or missing CSRF token"}), 403

    # Validate against the same DTO scripts/ dir master.sh run reads from.
    try:
        safe_path = _safe_name(f"{dag_id}.json", SCRIPTS_DIR)
    except ValueError as e:
        return jsonify({"error": f"Invalid path: {e}"}), 400

    if not os.path.isfile(safe_path):
        return jsonify({"error": "DAG script not found"}), 404

    # Single execution pathway: master.sh owns PID, log file naming, and
    # state.py record_start/record_finish hooks. The dashboard no longer
    # runs anything directly — it only ever triggers master.sh run.
    proc = subprocess.Popen(
        [MASTER_BIN, "run", dag_id],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return jsonify({"status": "started", "pid": proc.pid, "dag": dag_id}), 202


@app.route("/api/dags/<dag_id>/runs", methods=["GET"])
def dag_run_history(dag_id: str):
    # Since master.sh generates its own run_id async, the trigger response
    # above can't return it synchronously without risking the same PIPE
    # deadlock fixed earlier. Poll this instead to see recorded history.
    return jsonify(state.list_runs(limit=50, dag=dag_id))


def run_server(host: str = "127.0.0.1", port: int = 8080) -> None:
    init_storage()
    app.run(host=host, port=port, threaded=True)


if __name__ == "__main__":
    run_server()
