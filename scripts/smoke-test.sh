#!/usr/bin/env bash
set -euo pipefail

echo "Running CLI smoke tests..."

bash ./cmd/dbibih-cli nodejs --cleanup --help >/dev/null
bash ./cmd/dbibih-cli docker --cleanup --help >/dev/null
bash ./cmd/dbibih-cli docker status >/dev/null 2>&1 || true
bash ./cmd/dbibih-cli python --cleanup >/dev/null
bash ./cmd/dbibih-cli system --cleanup >/dev/null

echo "Smoke tests completed."
