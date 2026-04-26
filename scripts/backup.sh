#!/usr/bin/env bash

set -e

BACKUP_DIR="$HOME/backups"
TMP_DIR="$BACKUP_DIR/tmp_backup"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
ARCHIVE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"

# S3 / MinIO config
MC_ALIAS="hetzner"
MC_BUCKET="dbibih"

# Folders to backup (extend anytime)
BACKUP_ITEMS=(
  "$HOME/.ssh"
  "$HOME/.kube"
)

echo "🚀 Starting backup process..."

mkdir -p "$TMP_DIR"

# Copy folders
for item in "${BACKUP_ITEMS[@]}"; do
  if [ -e "$item" ]; then
    echo "📂 Copying $item"
    cp -a "$item" "$TMP_DIR/"
  else
    echo "⚠️ Skipping missing path: $item"
  fi
done

# Compress
echo "📦 Compressing backup..."
tar -czf "$ARCHIVE" -C "$TMP_DIR" .

# Cleanup temp directory
rm -rf "$TMP_DIR"

echo "✅ Backup created:"
echo "   $ARCHIVE"

# Upload to S3
echo "☁️ Uploading backup to S3..."
mc cp "$ARCHIVE" "$MC_ALIAS/$MC_BUCKET/"

echo "✅ Upload completed successfully"
