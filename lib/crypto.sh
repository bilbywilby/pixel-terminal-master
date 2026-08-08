#!/bin/sh
# OpenSSL AES-256-CBC PBKDF2 Cryptographic Envelope Manager
set -eu

KEY_FILE="$MASTER_STORAGE/.env_key"

get_or_create_key() {
    if [ ! -f "$KEY_FILE" ]; then
        log_warn "Generating new 256-bit master key..."
        openssl rand -hex 32 > "$KEY_FILE"
        chmod 600 "$KEY_FILE"
    fi
    cat "$KEY_FILE"
}

encrypt_value() {
    _raw_val="$1"
    _key=$(get_or_create_key)
    printf '%s' "$_raw_val" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -a -pass "pass:$_key"
}

decrypt_value() {
    _enc_val="$1"
    _key=$(get_or_create_key)
    printf '%s' "$_enc_val" | openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -a -pass "pass:$_key"
}
