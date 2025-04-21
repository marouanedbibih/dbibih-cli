#!/bin/bash

# Update package lists and upgrade packages
echo "Updating package lists..."
sudo apt-get update
echo "Upgrading installed packages..."
sudo apt-get upgrade -y
