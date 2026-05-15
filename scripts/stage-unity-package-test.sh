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

bash setup.sh com.selftest.unitypackage "Unity Package Self Test" "CI Bot" "SelfTest.UnityPackage"

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
