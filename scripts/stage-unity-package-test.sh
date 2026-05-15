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
if [ -d "__PACKAGE__.Tests" ]; then
    echo "Renaming __PACKAGE__.Tests to Tests"
    mv __PACKAGE__.Tests Tests
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
