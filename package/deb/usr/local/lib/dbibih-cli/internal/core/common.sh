#!/usr/bin/env bash

set -euo pipefail

color_enabled() {
    [[ -t 1 && -z "${NO_COLOR:-}" ]]
}

log_info() {
    echo "[INFO] $*"
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}
