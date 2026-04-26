#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Building package..."
bash "$ROOT_DIR/scripts/build-deb.sh"

echo "Installing package..."
bash "$ROOT_DIR/scripts/install-local.sh"

echo "Done."
