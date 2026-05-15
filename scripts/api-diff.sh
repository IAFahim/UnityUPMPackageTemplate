#!/usr/bin/env bash
# Usage: bash scripts/api-diff.sh
# Compares current API surface against the committed baseline.
# Exits 1 if any public members were REMOVED or RENAMED (breaking change).
set -euo pipefail

BASELINE="artifacts/api/baseline.txt"
CURRENT="artifacts/api/surface.txt"

bash scripts/api-surface.sh "$CURRENT"

if [ ! -f "$BASELINE" ]; then
    echo "  No baseline yet. Creating baseline from current surface."
    cp "$CURRENT" "$BASELINE"
    echo "  Commit artifacts/api/baseline.txt to track future API changes."
    exit 0
fi

REMOVED=$(comm -23 <(sort "$BASELINE") <(sort "$CURRENT"))
ADDED=$(comm -13 <(sort "$BASELINE") <(sort "$CURRENT"))

if [ -n "$REMOVED" ]; then
    echo ""
    echo "  ⚠  BREAKING CHANGE DETECTED"
    echo "  These public members were removed or renamed:"
    echo "$REMOVED" | sed 's/^/    /'
    echo ""
    echo "  If this is intentional: bump the MAJOR version (bash scripts/version.sh major)"
    echo "  Then update the baseline: cp artifacts/api/surface.txt artifacts/api/baseline.txt"
    exit 1
fi

if [ -n "$ADDED" ]; then
    echo "  New public members (non-breaking):"
    echo "$ADDED" | sed 's/^/    /'
fi

echo "  ✓ No breaking changes detected"
exit 0
