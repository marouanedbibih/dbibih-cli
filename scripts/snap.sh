#!/bin/bash
# snap.sh - Update Snap apps and remove old versions

echo "Starting Snap update..."

# Update all snap applications
sudo snap refresh

echo "Snap update completed."

# Remove old revisions of snap packages
echo "Removing old Snap revisions..."
set -e
for snap in $(snap list --all | awk '/disabled/{print $1, $2}'); do
    name=$(echo $snap | awk '{print $1}')
    revision=$(echo $snap | awk '{print $2}')
    echo "Removing old revision $revision of $name..."
    sudo snap remove "$name" --revision="$revision"
done

echo "Old Snap revisions removed."
echo "All done!"
