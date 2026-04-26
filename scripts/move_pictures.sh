#!/usr/bin/env bash
# ============================================================
# Script: organize_images.sh
# Purpose: Search entire system for images and move them to ~/Pictures
#          with duplicate detection, error handling, and optional dry-run.
# Author: DevOps Automation
# ============================================================

set -uo pipefail

# ----------------------
# Configuration
# ----------------------
DEST_DIR="$HOME/Pictures"
mkdir -p "$DEST_DIR"

LOG_FILE="$HOME/organize_images.log"
ERROR_LOG="$HOME/organize_images_errors.log"
DUPLICATE_LOG="$HOME/organize_images_duplicates.log"

# Dry-run and verbose flags
DRY_RUN=false
VERBOSE=false

# Exclude system directories, project folders, and all configuration directories
EXCLUDE_DIRS=(
    "/proc"
    "/sys"
    "/dev"
    "/run"
    "/snap"
    "/var/lib"
    "/usr/share"
    "/opt"
    "$HOME/Pictures"
    "$HOME/.android"
    "$HOME/.ansible"
    "$HOME/.aspnet"
    "$HOME/.aws"
    "$HOME/.azure"
    "$HOME/.azuredatastudio"
    "$HOME/.backup"
    "$HOME/.cache"
    "$HOME/.cert"
    "$HOME/.config"
    "$HOME/.cursor"
    "$HOME/.dartServer"
    "$HOME/.dart-tool"
    "$HOME/.dbtools"
    "$HOME/.docker"
    "$HOME/.dotnet"
    "$HOME/.flutter"
    "$HOME/.flutter-devtools"
    "$HOME/.gnome"
    "$HOME/.gnupg"
    "$HOME/.gphoto"
    "$HOME/.gradle"
    "$HOME/.java"
    "$HOME/.java-caller"
    "$HOME/.keys"
    "$HOME/.kube"
    "$HOME/.lemminx"
    "$HOME/.local"
    "$HOME/.m2"
    "$HOME/.mc"
    "$HOME/.minikube"
    "$HOME/.npm"
    "$HOME/.nuget"
    "$HOME/.nvm"
    "$HOME/.oh-my-zsh"
    "$HOME/.omnisharp"
    "$HOME/.openjfx"
    "$HOME/.pki"
    "$HOME/.poshthemes"
    "$HOME/.pub-cache"
    "$HOME/.pytest_cache"
    "$HOME/.redhat"
    "$HOME/.rest-client"
    "$HOME/.ServiceHub"
    "$HOME/.sonar"
    "$HOME/.sonarlint"
    "$HOME/.sqlsecrets"
    "$HOME/.ssh"
    "$HOME/.streamlit"
    "$HOME/.sts4"
    "$HOME/.subversion"
    "$HOME/.swt"
    "$HOME/.terraform.d"
    "$HOME/.texlive2023"
    "$HOME/.Upwork"
    "$HOME/.vscode"
    "$HOME/.vscode-react-native"
    "$HOME/.yarn"
    "$HOME/snap"
    "*/node_modules"
    "*/public"
    "*/assets"
    "*/.git"
    "*/.vscode"
    "*/.idea"
    "*/config"
    "*/conf"
    "*/.config"
    "*/etc"
    "*/.local"
    "*/.cache"
    "*/build"
    "*/dist"
    "*/target"
    "*/vendor"
)

# Image file extensions
IMAGE_EXTENSIONS=("jpg" "jpeg" "png" "gif" "bmp" "tiff" "tif" "webp" \
                  "cr2" "nef" "arw" "dng" "raf" "orf" "sr2" "pef" \
                  "svg" "ai" "eps" "ico" "icns" "heic" "heif" "psd" "xcf")

# Counters
total_found=0
moved_count=0
duplicate_count=0
error_count=0
total_size=0

# ----------------------
# Helper Functions
# ----------------------
log_info() { echo "[INFO] $1"; [[ "$VERBOSE" == true ]] && echo "[VERBOSE] $1"; }
log_error() { echo "[ERROR] $1" >> "$ERROR_LOG"; ((error_count++)); }
log_duplicate() { echo "[DUPLICATE] $1" >> "$DUPLICATE_LOG"; ((duplicate_count++)); }

# Function to build find exclusion arguments
build_exclude_args() {
    local args=()
    for d in "${EXCLUDE_DIRS[@]}"; do
        args+=(-path "$d" -prune -o)
    done
    echo "${args[@]}"
}

# Function to move a single file safely
move_file() {
    local src="$1"
    local ext="$2"

    # Organize by extension subfolder
    local ext_dir="$DEST_DIR/${ext^^}"  # Uppercase folder
    mkdir -p "$ext_dir"

    local filename
    filename=$(basename "$src")
    local dest="$ext_dir/$filename"

    # Get source file size for statistics
    local src_size
    src_size=$(stat -c%s "$src" 2>/dev/null || echo -1)

    # Duplicate detection
    if [[ -e "$dest" ]]; then
        local dest_size
        dest_size=$(stat -c%s "$dest" 2>/dev/null || echo -1)

        if [[ $src_size -eq $dest_size ]]; then
            # Check content checksum
            if [[ "$(sha256sum "$src" 2>/dev/null | awk '{print $1}')" == \
                  "$(sha256sum "$dest" 2>/dev/null | awk '{print $1}')" ]]; then
                log_duplicate "$src"
                # Delete the duplicate source file for cleanup
                if [[ "$DRY_RUN" == true ]]; then
                    log_info "[DRY-RUN] Would delete duplicate: $src"
                else
                    if rm "$src" 2>/dev/null; then
                        log_info "Deleted duplicate: $src"
                    else
                        log_error "Failed to delete duplicate: $src"
                    fi
                fi
                return
            fi
        fi
        # Rename file to avoid overwriting
        timestamp=$(date +%s)
        dest="$ext_dir/${filename%.*}_$timestamp.${filename##*.}"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would move: $src -> $dest"
    else
        if mv "$src" "$dest" 2>/dev/null; then
            log_info "Moved: $src -> $dest"
            ((moved_count++))
            ((total_size+=src_size))
        else
            log_error "$src"
        fi
    fi
}

# ----------------------
# Parse options
# ----------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            ;;
        --verbose)
            VERBOSE=true
            ;;
        --help)
            echo "Usage: $0 [--dry-run] [--verbose]"
            echo "  --dry-run  : Show what would happen without moving files"
            echo "  --verbose  : Show detailed processing info"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

# ----------------------
# Confirmation Prompt
# ----------------------
if [[ "$DRY_RUN" == false ]]; then
    read -rp "This will move all images to $DEST_DIR. Continue? [y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

# ----------------------
# Build find command
# ----------------------
EXCLUDE_ARGS=($(build_exclude_args))
FIND_CMD=(find "$HOME" "${EXCLUDE_ARGS[@]}" -type f \( )

for i in "${!IMAGE_EXTENSIONS[@]}"; do
    ext="${IMAGE_EXTENSIONS[$i]}"
    FIND_CMD+=(-iname "*.$ext")
    if [[ $i -lt $((${#IMAGE_EXTENSIONS[@]} - 1)) ]]; then
        FIND_CMD+=(-o)
    fi
done
FIND_CMD+=(\) -print)

# ----------------------
# Start Timer
# ----------------------
start_time=$(date +%s)

# ----------------------
# Process files
# ----------------------
while IFS= read -r img; do
    ((total_found++))
    ext="${img##*.}"
    move_file "$img" "$ext"
done < <("${FIND_CMD[@]}")

# ----------------------
# End Timer & Summary
# ----------------------
end_time=$(date +%s)
elapsed=$((end_time - start_time))

echo "================== Summary =================="
echo "Total images found    : $total_found"
echo "Successfully moved    : $moved_count"
echo "Skipped (duplicates)  : $duplicate_count"
echo "Skipped (errors)      : $error_count"
echo "Total size moved      : $(numfmt --to=iec --suffix=B $total_size)"
echo "Execution time        : ${elapsed}s"
echo "Logs: $LOG_FILE"
echo "Errors: $ERROR_LOG"
echo "Duplicates: $DUPLICATE_LOG"
echo "============================================="
