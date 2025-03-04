#!/bin/bash

# Clean up unnecessary packages and files
echo "Removing unnecessary packages..."
sudo apt-get autoremove -y
echo "Cleaning up local repository of retrieved package files..."
sudo apt-get clean
