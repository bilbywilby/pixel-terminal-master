#!/bin/sh
# Atomic Configuration Manager
set -eu

CONFIG_FILE="$MASTER_STORAGE/config.ini"

config_init() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat << 'EOF' > "$CONFIG_FILE"
storage_dir=~/.termux_master
log_level=info
notify_on_failure=1
default_editor=nano
wake_lock_enabled=1
EOF
        chmod 600 "$CONFIG_FILE"
    fi
}

config_get() {
    _key="$1"
    config_init
    _val=$(grep "^${_key}=" "$CONFIG_FILE" | cut -d'=' -f2-)
    printf '%s' "${_val:-}"
}

config_set() {
    _key="$1"
    _val="$2"
    config_init
    _tmp_cfg="$CONFIG_FILE.tmp.$$"
    if grep -q "^${_key}=" "$CONFIG_FILE"; then
        sed "s|^${_key}=.*|${_key}=${_val}|" "$CONFIG_FILE" > "$_tmp_cfg"
    else
        cat "$CONFIG_FILE" > "$_tmp_cfg"
        printf '%s=%s\n' "$_key" "$_val" >> "$_tmp_cfg"
    fi
    mv "$_tmp_cfg" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
}
