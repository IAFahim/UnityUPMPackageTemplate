#!/usr/bin/env bash
# ── Compact CI test results and logs ────────────────────────────
set -uo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RESET=$'\033[0m'

ARTIFACTS="${1:-artifacts}"

echo ""
echo "  ${BOLD}Compacting CI results...${RESET}"
echo ""

mkdir -p "$ARTIFACTS/compact"

# ── Compact NUnit XML test results ──────────────────────────────

XML_COUNT=0
for xml in $(find "$ARTIFACTS" -name "*.xml" -path "*/Test*" 2>/dev/null); do
    if [ -f "$xml" ]; then
        OUT="$ARTIFACTS/compact/$(basename "$xml" .xml).compact.txt"
        dotnet run --project Dev~/tools/TestResultsCompact -- \
            --input "$xml" --output "$OUT" 2>/dev/null || true
        ((XML_COUNT++)) || true
        echo "  ${GREEN}✓${RESET} Compacted: $(basename "$xml")"
    fi
done

# ── Compact Unity Editor logs ───────────────────────────────────

LOG_COUNT=0
for log in $(find "$ARTIFACTS" -name "*.log" 2>/dev/null); do
    if [ -f "$log" ]; then
        OUT="$ARTIFACTS/compact/$(basename "$log" .log).compact.txt"
        dotnet run --project Dev~/tools/TestLogCompact -- \
            --input "$log" --output "$OUT" 2>/dev/null || true
        ((LOG_COUNT++)) || true
        echo "  ${GREEN}✓${RESET} Compacted: $(basename "$log")"
    fi
done

# ── Generate summary ────────────────────────────────────────────

SUMMARY="$ARTIFACTS/compact/summary.md"
cat > "$SUMMARY" <<EOF
# CI Results Summary

Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Test Results
$(find "$ARTIFACTS/compact" -name "*.compact.txt" -not -name "*Log*" -exec cat {} \; 2>/dev/null || echo "No test results found.")

## Editor Logs
$(find "$ARTIFACTS/compact" -name "*Log*.compact.txt" -exec cat {} \; 2>/dev/null || echo "No editor logs found.")
EOF

# Append to GITHUB_STEP_SUMMARY if available
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    cat "$SUMMARY" >> "$GITHUB_STEP_SUMMARY"
fi

echo ""
echo "  ${GREEN}✓${RESET} Compacted $XML_COUNT test results, $LOG_COUNT logs"
echo "  Output: $ARTIFACTS/compact/"
echo ""
