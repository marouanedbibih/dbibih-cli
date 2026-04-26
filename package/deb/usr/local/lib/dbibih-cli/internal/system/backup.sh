#!/bin/bash

# Backup important files to a specified directory
BACKUP_DIR="/home/$(whoami)/backup"
mkdir -p "$BACKUP_DIR"
echo "Backing up important files to $BACKUP_DIR..."
tar -czf "$BACKUP_DIR/backup_$(date +%F).tar.gz" /home/$(whoami)
