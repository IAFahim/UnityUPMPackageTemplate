#!/usr/bin/env bash
# ── Generate AI context dump for LLM consumption ────────────────
set -uo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RESET=$'\033[0m'

OUTPUT="${1:-artifacts/ai/codebase.md}"
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
mkdir -p "$(dirname "$OUTPUT")"

echo ""
echo "  ${BOLD}Generating AI context...${RESET}"

# Use GC tool if available, otherwise fallback to npx
if command -v gc >/dev/null 2>&1; then
    GC_CMD="gc"
elif command -v npx >/dev/null 2>&1; then
    GC_CMD="npx -y @iafahim/gc"
else
    GC_CMD=""
fi

if [ -n "$GC_CMD" ]; then
    echo "  Using tool: $GC_CMD"
    $GC_CMD --output "$OUTPUT"
    $GC_CMD --brain --compress --output "${OUTPUT%.md}.compact.md" 2>/dev/null || true
else
    # Fallback to manual bash version if no node/npm
    echo "  ${YELLOW}⚠${RESET} gc/npx not found. Using bash fallback."
    {
        echo "# Codebase: $(basename "$(pwd)")"
        echo "## Structure"
        find . -not -path './.git/*' -not -path '*/bin/*' -not -path '*/obj/*' | sort | head -100
        echo "## package.json"
        cat package.json 2>/dev/null
    } > "$OUTPUT"
fi

echo "  ${GREEN}✓${RESET} AI context generated: $OUTPUT"
echo ""
