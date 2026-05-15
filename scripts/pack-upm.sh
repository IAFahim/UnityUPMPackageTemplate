#!/usr/bin/env bash
# ── Pack UPM package as .tgz ────────────────────────────────────
set -uo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' RESET=$'\033[0m'

VERSION=$(python3 -c "import json; print(json.load(open('package.json'))['version'])" 2>/dev/null || echo "0.0.0")
NAME=$(python3 -c "import json; print(json.load(open('package.json'))['name'])" 2>/dev/null || echo "unknown")

OUTPUT_DIR="${1:-dist}"
mkdir -p "$OUTPUT_DIR"

echo ""
echo "  ${BOLD}Packing UPM .tgz...${RESET}"
echo "  Package: $NAME v$VERSION"
echo ""

# Create a temp staging directory
STAGING="/tmp/upm-pack-$$"
cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT

mkdir -p "$STAGING/$NAME"

# Copy package files (exclude dev/build artifacts)
rsync -a \
    --exclude='.git' \
    --exclude='.github' \
    --exclude='bin' \
    --exclude='obj' \
    --exclude='artifacts' \
    --exclude='.gameci' \
    --exclude='dist' \
    --exclude='tools' \
    --exclude='scripts' \
    --exclude='src' \
    --exclude='tests' \
    --exclude='benchmarks' \
    --exclude='*.slnx' \
    --exclude='global.json' \
    --exclude='Directory.Build.props' \
    --exclude='.editorconfig' \
    --exclude='.DS_Store' \
    ./ "$STAGING/$NAME/"

cd "$STAGING"

# Create tarball
OUTPUT_FILE="$OLDPWD/$OUTPUT_DIR/${NAME}-${VERSION}.tgz"
tar czf "$OUTPUT_FILE" "$NAME"

if [ -f "$OUTPUT_FILE" ]; then
    SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "  ${GREEN}✓${RESET} $OUTPUT_FILE ($SIZE)"
    echo ""
else
    echo "  ${RED}✗${RESET} Failed to create .tgz"
    exit 1
fi
