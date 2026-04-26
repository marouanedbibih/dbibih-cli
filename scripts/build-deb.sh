#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PKG_ROOT="$ROOT_DIR/package/deb"
STAGING_LIB="$PKG_ROOT/usr/local/lib/dbibih-cli"
OUT_DEB="$ROOT_DIR/dbibih-cli.deb"

echo "Building dbibih-cli Debian package..."

rm -rf "$STAGING_LIB"
mkdir -p "$STAGING_LIB"

cp -r "$ROOT_DIR/cmd" "$STAGING_LIB/"
cp -r "$ROOT_DIR/internal" "$STAGING_LIB/"

chmod +x "$PKG_ROOT/usr/local/bin/dbibih-cli"
chmod +x "$STAGING_LIB/cmd/dbibih-cli"
find "$STAGING_LIB/internal" -type f -name "*.sh" -exec chmod +x {} \;
chmod 755 "$PKG_ROOT/DEBIAN/postinst" "$PKG_ROOT/DEBIAN/prerm" "$PKG_ROOT/DEBIAN/postrm"

dpkg-deb --build "$PKG_ROOT" "$OUT_DEB"

echo "Package created: $OUT_DEB"
