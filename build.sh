#!/bin/bash
set -e

echo "📦 Building the dbibih CLI package..."

# Build the Debian package
dpkg-deb --build cli dbibih-cli.deb

echo "✅ Package built successfully."

echo "📥 Installing the package..."

# Install the generated package
sudo dpkg -i dbibih-cli.deb

echo "🎉 Package installed successfully!"
