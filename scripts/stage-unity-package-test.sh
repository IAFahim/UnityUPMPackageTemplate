#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-.gameci/package-under-test}"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
rm -rf "$OUT"
mkdir -p "$(dirname "$OUT")"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

cp -R "$ROOT" "$TMP/template"
cd "$TMP/template"
rm -rf .git .gameci artifacts bin obj

bash setup.sh com.gameci.selftest "Unity Package Self Test" "GameCI" "GameCI.SelfTest"

# GameCI packageMode: true expects a folder named 'Tests' at the package root
# After setup.sh, the structure is com.gameci.selftest/Tests/
PKG_DIR=$(find . -maxdepth 1 -type d -name 'com.*' | head -1)
if [ -n "$PKG_DIR" ] && [ -d "$PKG_DIR/Tests" ]; then
    echo "Moving $PKG_DIR/Tests to root for GameCI"
    mv "$PKG_DIR/Tests" Tests
fi

# Remove dev-only folders before Unity sees the package.
rm -rf \
    Dev~ \
    src \
    tests \
    benchmarks \
    tools \
    Skills~ \
    .github \
    artifacts \
    bin \
    obj \
    .gameci

mkdir -p "$ROOT/$(dirname "$OUT")"
cp -R "$TMP/template" "$ROOT/$OUT"

echo "Staged package content:"
ls -la "$ROOT/$OUT"

cd "$ROOT/$OUT"

if grep -R "__[A-Z_]*__" \
    --include='*.cs' \
    --include='*.json' \
    --include='*.asmdef' \
    .; then
    echo "FAIL: placeholders remain in staged Unity package"
    exit 1
fi

echo "Staged Unity package at $OUT"
