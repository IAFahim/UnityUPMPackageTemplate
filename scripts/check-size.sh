#!/usr/bin/env bash
# ── Check package size budget ───────────────────────────────────
set -uo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' RESET=$'\033[0m'

MAX_KB="${1:-500}"  # Default 500KB budget

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

echo ""
echo "  ${BOLD}Package size check (max ${MAX_KB}KB)${RESET}"
echo ""

# Calculate size excluding bin/obj/.git
TOTAL=$(find . -not -path './.git/*' -not -path '*/bin/*' -not -path '*/obj/*' \
    -not -path '*/artifacts/*' -not -name '*.dll' \
    -type f -exec cat {} + | wc -c)

TOTAL_KB=$((TOTAL / 1024))

COLOR="brightgreen"
[ "$TOTAL_KB" -gt 200 ] && COLOR="yellow"
[ "$TOTAL_KB" -gt "$MAX_KB" ] && COLOR="red"

mkdir -p artifacts/badges
echo "https://img.shields.io/badge/size-${TOTAL_KB}KB-${COLOR}" > artifacts/badges/size.txt

# Per-category breakdown
CS_KB=$(find . -name "*.cs" -not -path '*/bin/*' -not -path '*/obj/*' -type f -exec cat {} + 2>/dev/null | wc -c | awk '{printf "%.0f", $1/1024}')
JSON_KB=$(find . -name "*.json" -not -path '*/bin/*' -not -path '*/obj/*' -type f -exec cat {} + 2>/dev/null | wc -c | awk '{printf "%.0f", $1/1024}')

echo "  Source (.cs):  ${CS_KB:-0}KB"
echo "  Config (.json): ${JSON_KB:-0}KB"
echo "  Total:         ${TOTAL_KB}KB"
echo ""

if [ "$TOTAL_KB" -le "$MAX_KB" ]; then
    echo "  ${GREEN}✓${RESET} Within ${MAX_KB}KB budget"
    exit 0
else
    echo "  ${RED}✗${RESET} Exceeds ${MAX_KB}KB budget by $((TOTAL_KB - MAX_KB))KB"
    # Show largest files
    echo ""
    echo "  Largest files:"
    find . -not -path './.git/*' -not -path '*/bin/*' -not -path '*/obj/*' \
        -type f -exec du -k {} + 2>/dev/null | sort -rn | head -10 | while read -r line; do
        echo "    $line"
    done
    exit 1
fi
