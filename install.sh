#!/bin/sh
# Termux Master Ultra — Installer
# POSIX sh. Idempotent: safe to re-run. Supports Termux and plain Debian userlands.
set -eu

# ---------------------------------------------------------------------------
# Exit code contract (matches lib/common.sh conventions)
# ---------------------------------------------------------------------------
EXIT_OK=0
EXIT_GENERAL=1
EXIT_MISSING_DEP=2
EXIT_BAD_ARGS=3
EXIT_MISSING_CMD=127

# ---------------------------------------------------------------------------
# Defaults (overridable via flags)
# ---------------------------------------------------------------------------
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MASTER_STORAGE="${MASTER_STORAGE:-$HOME/.termux_master}"
PREFIX="${PREFIX:-$HOME/bin}"
DRY_RUN=0
NO_RC=0
UNINSTALL=0
PURGE_DATA=0

RC_MARK_START="# >>> termux-master-ultra >>>"
RC_MARK_END="# <<< termux-master-ultra <<<"

# ---------------------------------------------------------------------------
# Logging (falls back to plain printf if lib/common.sh isn't reachable yet)
# ---------------------------------------------------------------------------
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck source=/dev/null
    . "$SCRIPT_DIR/lib/common.sh"
else
    log_msg() { _level="$1"; shift; printf '[%s] %s\n' "$_level" "$*"; }
    log_info() { log_msg "INFO" "$@"; }
    log_warn() { log_msg "WARN" "$@" >&2; }
    log_err()  { log_msg "ERROR" "$@" >&2; }
fi

run() {
    # Wrapper so --dry-run can no-op any state-changing command uniformly.
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

usage() {
    cat <<EOF
Termux Master Ultra installer

Usage: install.sh [options]

Options:
  --prefix DIR     Install the 'master' launcher symlink into DIR (default: \$HOME/bin)
  --dry-run        Print what would happen without changing anything
  --no-rc          Skip editing shell rc files (~/.bashrc, ~/.profile)
  --uninstall      Remove the launcher symlink and rc block (data is kept)
  --purge-data     With --uninstall, also delete \$MASTER_STORAGE (irreversible)
  -h, --help       Show this help

Environment:
  MASTER_STORAGE   Where app state lives (default: \$HOME/.termux_master)
EOF
}

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)
            [ $# -ge 2 ] || { log_err "--prefix requires a directory argument"; exit "$EXIT_BAD_ARGS"; }
            PREFIX="$2"; shift 2 ;;
        --prefix=*)
            PREFIX="${1#--prefix=}"; shift ;;
        --dry-run)
            DRY_RUN=1; shift ;;
        --no-rc)
            NO_RC=1; shift ;;
        --uninstall)
            UNINSTALL=1; shift ;;
        --purge-data)
            PURGE_DATA=1; shift ;;
        -h|--help)
            usage; exit "$EXIT_OK" ;;
        *)
            log_err "Unknown argument: $1"
            usage
            exit "$EXIT_BAD_ARGS" ;;
    esac
done

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
check_cmd() {
    _cmd="$1"; _hint="$2"
    if ! command -v "$_cmd" >/dev/null 2>&1; then
        log_err "Missing required dependency: $_cmd"
        [ -n "$_hint" ] && log_err "  -> $_hint"
        return 1
    fi
    return 0
}

check_dependencies() {
    _missing=0
    check_cmd python3 "apt install python3" || _missing=1
    check_cmd jq      "apt install jq"       || _missing=1
    check_cmd openssl "apt install openssl"  || _missing=1

    if command -v python3 >/dev/null 2>&1; then
        _pyver=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
        case "$_pyver" in
            3.9|3.1[0-9]|3.[2-9][0-9]) : ;;  # 3.9 through 3.99 accepted
            *)
                log_warn "Python $_pyver detected; 3.9+ is assumed. Proceeding anyway."
                ;;
        esac
    fi

    if ! python3 -m venv --help >/dev/null 2>&1; then
        log_err "python3 -m venv is unavailable."
        log_err "  -> apt install python3-venv (or python3.X-venv matching your version)"
        _missing=1
    fi

    if [ "$_missing" -eq 1 ]; then
        log_err "Resolve missing dependencies above, then re-run install.sh"
        exit "$EXIT_MISSING_DEP"
    fi
    log_info "All required dependencies present."
}

# ---------------------------------------------------------------------------
# Directory + file layout
# ---------------------------------------------------------------------------
ensure_storage_layout() {
    for _dir in scripts envs schedules backups plugins bin dags logs state lib; do
        _target="$MASTER_STORAGE/$_dir"
        if [ ! -d "$_target" ]; then
            run mkdir -p "$_target"
            run chmod 700 "$_target"
        else
            log_info "Exists, skipping: $_target"
        fi
    done
}

copy_if_changed() {
    # Idempotent copy: skip if source and dest are already identical.
    _src="$1"; _dst="$2"
    if [ -f "$_dst" ] && cmp -s "$_src" "$_dst" 2>/dev/null; then
        log_info "Unchanged, skipping: $_dst"
        return 0
    fi
    run cp "$_src" "$_dst"
    log_info "Installed: $_dst"
}

install_app_files() {
    [ -f "$SCRIPT_DIR/master.sh" ] && copy_if_changed "$SCRIPT_DIR/master.sh" "$MASTER_STORAGE/bin/master.sh"
    if [ -f "$MASTER_STORAGE/bin/master.sh" ] || [ "$DRY_RUN" -eq 1 ]; then
        run chmod 700 "$MASTER_STORAGE/bin/master.sh" 2>/dev/null || true
    fi

    if [ -d "$SCRIPT_DIR/lib" ]; then
        for _f in "$SCRIPT_DIR"/lib/*.sh; do
            [ -f "$_f" ] || continue
            copy_if_changed "$_f" "$MASTER_STORAGE/lib/$(basename "$_f")"
        done
    fi

    for _pyf in dashboard.py state.py index.html; do
        [ -f "$SCRIPT_DIR/$_pyf" ] && copy_if_changed "$SCRIPT_DIR/$_pyf" "$MASTER_STORAGE/bin/$_pyf"
    done
}

# ---------------------------------------------------------------------------
# Python virtualenv for dashboard deps (sidesteps PEP 668 externally-managed-env)
# ---------------------------------------------------------------------------
setup_venv() {
    _venv="$MASTER_STORAGE/venv"
    if [ -x "$_venv/bin/python3" ]; then
        log_info "venv already present: $_venv"
    else
        run python3 -m venv "$_venv"
        log_info "Created venv: $_venv"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] %s/bin/pip install --upgrade pip flask psutil\n' "$_venv"
        return 0
    fi

    "$_venv/bin/pip" install --quiet --upgrade pip
    "$_venv/bin/pip" install --quiet flask psutil
    log_info "Dashboard dependencies installed into venv."
}

# ---------------------------------------------------------------------------
# Launcher symlink
# ---------------------------------------------------------------------------
install_launcher() {
    run mkdir -p "$PREFIX"
    _link="$PREFIX/master"
    if [ -L "$_link" ] && [ "$(readlink "$_link")" = "$MASTER_STORAGE/bin/master.sh" ]; then
        log_info "Launcher already correct: $_link"
        return 0
    fi
    if [ -e "$_link" ] && [ ! -L "$_link" ]; then
        log_err "$_link exists and is not a symlink we manage; refusing to overwrite."
        exit "$EXIT_GENERAL"
    fi
    run ln -sf "$MASTER_STORAGE/bin/master.sh" "$_link"
    log_info "Linked $_link -> $MASTER_STORAGE/bin/master.sh"
}

remove_launcher() {
    _link="$PREFIX/master"
    if [ -L "$_link" ]; then
        run rm -f "$_link"
        log_info "Removed launcher: $_link"
    fi
}

# ---------------------------------------------------------------------------
# Idempotent PATH export in shell rc files
# ---------------------------------------------------------------------------
add_rc_block() {
    [ "$NO_RC" -eq 1 ] && { log_info "Skipping rc edits (--no-rc)"; return 0; }
    for _rc in "$HOME/.bashrc" "$HOME/.profile"; do
        [ -f "$_rc" ] || continue
        if grep -qF "$RC_MARK_START" "$_rc" 2>/dev/null; then
            log_info "PATH block already present in $_rc"
            continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            printf '[dry-run] append PATH block to %s\n' "$_rc"
            continue
        fi
        {
            printf '\n%s\n' "$RC_MARK_START"
            printf 'export MASTER_STORAGE="%s"\n' "$MASTER_STORAGE"
            printf 'case ":$PATH:" in *":%s:"*) ;; *) export PATH="%s:$PATH" ;; esac\n' "$PREFIX" "$PREFIX"
            printf '%s\n' "$RC_MARK_END"
        } >> "$_rc"
        log_info "Appended PATH block to $_rc"
    done
}

remove_rc_block() {
    for _rc in "$HOME/.bashrc" "$HOME/.profile"; do
        [ -f "$_rc" ] || continue
        grep -qF "$RC_MARK_START" "$_rc" 2>/dev/null || continue
        if [ "$DRY_RUN" -eq 1 ]; then
            printf '[dry-run] remove PATH block from %s\n' "$_rc"
            continue
        fi
        _tmp="$_rc.tmp.$$"
        awk -v start="$RC_MARK_START" -v end="$RC_MARK_END" '
            $0 == start { skip=1; next }
            $0 == end   { skip=0; next }
            !skip { print }
        ' "$_rc" > "$_tmp"
        mv "$_tmp" "$_rc"
        log_info "Removed PATH block from $_rc"
    done
}

# ---------------------------------------------------------------------------
# Uninstall path
# ---------------------------------------------------------------------------
do_uninstall() {
    remove_launcher
    remove_rc_block
    if [ "$PURGE_DATA" -eq 1 ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            printf '[dry-run] rm -rf %s\n' "$MASTER_STORAGE"
        else
            rm -rf "$MASTER_STORAGE"
            log_info "Purged $MASTER_STORAGE"
        fi
    else
        log_info "Data preserved at $MASTER_STORAGE (use --purge-data to remove)"
    fi
    log_info "Uninstall complete."
    exit "$EXIT_OK"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if [ "$UNINSTALL" -eq 1 ]; then
    do_uninstall
fi

log_info "Installing Termux Master Ultra"
log_info "  MASTER_STORAGE = $MASTER_STORAGE"
log_info "  PREFIX         = $PREFIX"
[ "$DRY_RUN" -eq 1 ] && log_info "  Mode           = dry-run (no changes will be made)"

check_dependencies
ensure_storage_layout
install_app_files
setup_venv
install_launcher
add_rc_block

log_info "Install complete."
log_info "Run 'master setup' to finish initializing, or restart your shell to pick up PATH changes."
exit "$EXIT_OK"
