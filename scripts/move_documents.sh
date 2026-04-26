#!/usr/bin/env bash
# ============================================================
# Script: home_cleanup.sh
# Purpose: Safely move documents from home to ~/Documents
#          Organize by type, handle duplicates, skip permission errors
# Author: DevOps Automation
# ============================================================

set -uo pipefail   # Don't exit on errors, treat unset variables as errors

# ----------------------
# Variables
# ----------------------
HOME_DIR="$HOME"
TARGET_DIR="$HOME_DIR/Documents"
LOG_FILE="$HOME_DIR/home_cleanup.log"
ERROR_LOG="$HOME_DIR/home_cleanup_errors.log"

mkdir -p "$TARGET_DIR"
echo "[INFO] Target directory: $TARGET_DIR"
echo "[INFO] Logs -> $LOG_FILE, Errors -> $ERROR_LOG"

# ----------------------
# Document types mapping
# ----------------------
declare -A DOC_TYPES=(
    ["pdf"]="PDFs"
    ["doc"]="Word"
    ["docx"]="Word"
    ["xls"]="Excel"
    ["xlsx"]="Excel"
    ["ppt"]="PowerPoint"
    ["pptx"]="PowerPoint"
    ["txt"]="Text"
    ["md"]="Markdown"
    ["csv"]="CSV"
    ["odt"]="OpenDocument"
)

# ----------------------
# Function to safely move files
# ----------------------
move_file() {
    local src="$1"
    local ext="$2"
    local type_dir="${DOC_TYPES[$ext]:-Others}"
    local dest_dir="$TARGET_DIR/$type_dir"

    mkdir -p "$dest_dir"

    local base_name
    base_name=$(basename "$src")
    local target_file="$dest_dir/$base_name"

    # Handle duplicates
    if [[ -e "$target_file" ]]; then
        timestamp=$(date +%s)
        target_file="$dest_dir/${base_name%.*}_$timestamp.${base_name##*.}"
    fi

    # Move file, log success or error
    if mv "$src" "$target_file" 2>>"$ERROR_LOG"; then
        echo "[INFO] Moved $src → $target_file" >> "$LOG_FILE"
    else
        echo "[WARN] Skipped $src due to error" >> "$ERROR_LOG"
    fi
}

# ----------------------
# Main loop: process all document types
# ----------------------
for ext in "${!DOC_TYPES[@]}"; do
    find "$HOME_DIR" \
        -path "$TARGET_DIR" -prune -o \
        -path "$HOME_DIR/snap" -prune -o \
        -path "$HOME_DIR/.cache" -prune -o \
        -path "$HOME_DIR/.local/share/Trash" -prune -o \
        -type f -iname "*.$ext" -print 2>/dev/null | while read -r file; do
            move_file "$file" "$ext"
    done
done

echo "[SUCCESS] Document cleanup completed!"
echo "[INFO] Check $LOG_FILE and $ERROR_LOG for details."
