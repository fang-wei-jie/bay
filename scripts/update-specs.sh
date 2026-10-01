#!/bin/sh
# Installs the withfig completion specs that Bay serves locally through `spec://`.
# Usage: scripts/update-specs.sh [version]   (defaults to the latest @withfig/autocomplete)
set -eu

VERSION=${1:-latest}

case "$(uname -s)" in
  Darwin) DATA_DIR="$HOME/Library/Application Support/bay" ;;
  *) DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bay" ;;
esac
SPECS_DIR="$DATA_DIR/autocomplete/specs"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# npm pack checks the tarball against the registry's integrity hash.
TARBALL=$(cd "$TMP" && npm pack --silent "@withfig/autocomplete@$VERSION")
tar -xzf "$TMP/$TARBALL" -C "$TMP"
test -f "$TMP/package/build/index.json"

mkdir -p "$(dirname "$SPECS_DIR")"
rm -rf "$SPECS_DIR.new"
mv "$TMP/package/build" "$SPECS_DIR.new"
rm -rf "$SPECS_DIR"
mv "$SPECS_DIR.new" "$SPECS_DIR"

echo "Installed ${TARBALL%.tgz} into $SPECS_DIR"
