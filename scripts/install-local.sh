#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEB_PATH="$ROOT_DIR/dbibih-cli.deb"

if [[ ! -f "$DEB_PATH" ]]; then
    echo "Deb package not found: $DEB_PATH"
    echo "Run scripts/build-deb.sh first."
    exit 1
fi

echo "Installing $DEB_PATH ..."
sudo dpkg -i "$DEB_PATH"
echo "Installation completed."
