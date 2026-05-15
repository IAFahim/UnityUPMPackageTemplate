#!/usr/bin/env bash
# Usage: bash scripts/generate-compatibility-matrix.sh
# Outputs a Markdown compatibility table to Documentation~/compatibility.md
set -uo pipefail

# Read test results from artifacts
RESULTS_DIR="${1:-artifacts}"
OUT="Documentation~/compatibility.md"

echo "# Unity Compatibility" > "$OUT"
echo "" >> "$OUT"
echo "| Unity Version | Status | Notes |" >> "$OUT"
echo "|---|---|---|" >> "$OUT"

source scripts/unity-versions.sh 2>/dev/null || true

for ver in "${UNITY_TEST_VERSIONS[@]}"; do
    RESULT_FILE=$(find "$RESULTS_DIR" -name "*.xml" -path "*$ver*" 2>/dev/null | head -1)
    if [ -z "$RESULT_FILE" ]; then
        echo "| $ver | ⏳ Not tested | |" >> "$OUT"
    else
        FAILED=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('$RESULT_FILE')
print(tree.getroot().get('failed','0'))
" 2>/dev/null || echo "?")
        if [ "$FAILED" = "0" ]; then
            echo "| $ver | ✅ Passing | |" >> "$OUT"
        else
            echo "| $ver | ❌ $FAILED failures | |" >> "$OUT"
        fi
    fi
done

echo "" >> "$OUT"
echo "_Last updated: $(date -u +%Y-%m-%d)_" >> "$OUT"

echo "  ✓ Compatibility matrix → $OUT"
