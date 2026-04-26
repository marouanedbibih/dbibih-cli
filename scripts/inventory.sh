#!/usr/bin/env bash
# ============================================================
# Script: 01_create_inventory.sh
# Purpose: Collect a full inventory of user-installed packages,
#          applications, services, containers, repos, and dotfiles.
# Author: Senior DevOps & Cloud Engineer (for Marouane)
# ============================================================

set -euo pipefail

# --- Variables ---
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="inventory_$TIMESTAMP"

# Create inventory directory
mkdir -p "$OUTPUT_DIR"

echo "[INFO] Inventory directory created: $OUTPUT_DIR"

# ------------------------------------------------------------
# 1. List all explicitly user-installed APT packages
# ------------------------------------------------------------
echo "[INFO] Collecting user-installed apt packages..."
apt-mark showmanual \
    | grep -v -E "^(base-files|bash|coreutils|dpkg|gcc|libc6|login|systemd|util-linux|ubuntu-minimal)" \
    > "$OUTPUT_DIR/user-installed-packages.txt"

# ------------------------------------------------------------
# 2. List Snap and Flatpak applications
# ------------------------------------------------------------
echo "[INFO] Collecting Snap and Flatpak packages..."
{
    echo "=== Snap List ==="
    snap list 2>/dev/null || echo "Snap not installed."

    echo -e "\n=== Flatpak List ==="
    flatpak list --app 2>/dev/null || echo "Flatpak not installed."
} > "$OUTPUT_DIR/snap-flatpak-list.txt"

# ------------------------------------------------------------
# 3. List running services (systemd) and Docker containers
# ------------------------------------------------------------
echo "[INFO] Collecting systemd services and Docker containers..."
{
    echo "=== Systemd Active Services ==="
    systemctl list-units --type=service --state=running --no-pager

    echo -e "\n=== Docker Containers ==="
    if command -v docker &>/dev/null; then
        docker ps -a
    else
        echo "Docker not installed."
    fi
} > "$OUTPUT_DIR/services-containers.txt"

# ------------------------------------------------------------
# 4. Find repo files in apt/yum directories
# ------------------------------------------------------------
echo "[INFO] Collecting repository definitions..."
{
    echo "=== APT sources.list.d ==="
    ls -1 /etc/apt/sources.list.d/*.list 2>/dev/null || echo "No APT repo files found."

    echo -e "\n=== YUM repos.d ==="
    ls -1 /etc/yum.repos.d/*.repo 2>/dev/null || echo "No YUM repo files found."
} > "$OUTPUT_DIR/repositories.txt"

# ------------------------------------------------------------
# 5. List dotfiles in home directory
# ------------------------------------------------------------
echo "[INFO] Collecting dotfiles and dotfolders..."
DOTFILES_OUTPUT="$OUTPUT_DIR/dotfiles-list.txt"

find "$HOME" -maxdepth 1 -type f -name ".*" \
    ! -name ".bash_history" \
    ! -name ".cache" \
    ! -name ".local" \
    ! -name ".DS_Store" \
    > "$DOTFILES_OUTPUT.files"

find "$HOME" -maxdepth 1 -type d -name ".*" \
    ! -name "." \
    ! -name ".." \
    ! -name ".cache" \
    ! -name ".local" \
    ! -name ".Trash" \
    > "$DOTFILES_OUTPUT.dirs"

echo "=== Dotfiles ===" > "$DOTFILES_OUTPUT"
cat "$DOTFILES_OUTPUT.files" >> "$DOTFILES_OUTPUT"
echo -e "\n=== Dotfolders ===" >> "$DOTFILES_OUTPUT"
cat "$DOTFILES_OUTPUT.dirs" >> "$DOTFILES_OUTPUT"
rm -f "$DOTFILES_OUTPUT.files" "$DOTFILES_OUTPUT.dirs"

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
echo "[SUCCESS] Inventory created in directory: $OUTPUT_DIR"
echo "Files:"
ls -1 "$OUTPUT_DIR"
