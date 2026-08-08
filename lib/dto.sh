#!/bin/sh
# DTO Processing Module
set -eu

validate_script_dto() {
    _dto_file="$1"
    assert_cmd jq
    if ! jq -e '.id and .command' "$_dto_file" >/dev/null 2>&1; then
        log_err "Invalid Script DTO: Missing required 'id' or 'command' field in $_dto_file"
        return 1
    fi
    return 0
}

import_script_dto() {
    _dto_file="$1"
    validate_script_dto "$_dto_file"
    _id=$(jq -r '.id' "$_dto_file")
    _target="$MASTER_STORAGE/scripts/${_id}.json"
    cp "$_dto_file" "$_target"
    chmod 600 "$_target"
    log_info "Script DTO successfully imported with ID: $_id"
}
