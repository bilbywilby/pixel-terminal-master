#!/bin/sh
# Plugin Lifecycle Manager
set -eu

PLUGINS_DIR="$MASTER_STORAGE/plugins"

load_plugins() {
    if [ ! -d "$PLUGINS_DIR" ]; then
        return 0
    fi
    for _plugin in "$PLUGINS_DIR"/*.sh; do
        if [ -r "$_plugin" ]; then
            log_debug "Loading plugin source: $_plugin"
            . "$_plugin"
            _plugin_name=$(basename "$_plugin" .sh)
            if command -v "plugin_${_plugin_name}_init" >/dev/null 2>&1; then
                "plugin_${_plugin_name}_init"
            fi
        fi
    done
}

list_plugins() {
    if [ -d "$PLUGINS_DIR" ]; then
        ls -1 "$PLUGINS_DIR"/*.sh 2>/dev/null | xargs -n 1 basename 2>/dev/null || log_info "No plugins loaded."
    fi
}
