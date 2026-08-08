pixel-terminal-master/ (orchestration code)
    ├── master.sh ──────────────► CLI entry point ($MASTER_STORAGE)
    ├── state.py ───────────────► SQLite run tracking (CLI & Python API)
    └── url_cleaner_workflow.json ─► DTO for import

~/.termux_master/ (runtime storage)
    ├── bin/state.py ───────────► Copied state.py for master.sh calls
    ├── scripts/*.json ─────────► Imported DTOs
    ├── logs/*.log ─────────────► Execution logs
    └── envs/global.env ────────► Environment variables
