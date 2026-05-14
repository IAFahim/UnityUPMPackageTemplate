#!/usr/bin/env bash
# ── Generate AI context dump for LLM consumption ────────────────
set -uo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RESET=$'\033[0m'

OUTPUT="${1:-artifacts/ai/codebase.md}"

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

mkdir -p "$(dirname "$OUTPUT")"

echo ""
echo "  ${BOLD}Generating AI context...${RESET}"
echo "  Output: $OUTPUT"
echo ""

{
    echo "# Codebase: $(basename "$(pwd)")"
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""

    # Package manifest
    if [ -f "package.json" ]; then
        echo "## package.json"
        echo ""
        echo '```json'
        cat package.json
        echo '```'
        echo ""
    fi

    # Directory structure
    echo "## Structure"
    echo ""
    echo '```'
    find . -not -path './.git/*' -not -path '*/bin/*' -not -path '*/obj/*' \
        -not -path '*/artifacts/*' -not -path '*/.gameci/*' \
        | sort | head -100
        echo '```'
    echo ""

    # Source files
    echo "## Source"
    echo ""

    find . -name "*.cs" -not -path '*/bin/*' -not -path '*/obj/*' -not -path './.git/*' \
        -not -path '*/artifacts/*' | sort | while read -r f; do
        echo "### $f"
        echo ""
        echo '```csharp'
        cat "$f"
        echo '```'
        echo ""
    done

    # asmdef files
    echo "## Assembly Definitions"
    echo ""
    find . -name "*.asmdef" -not -path './.git/*' | sort | while read -r f; do
        echo "### $f"
        echo ""
        echo '```json'
        cat "$f"
        echo '```'
        echo ""
    done

    # CI workflows
    if [ -d ".github/workflows" ]; then
        echo "## CI Workflows"
        echo ""
        find .github/workflows -name "*.yml" | sort | while read -r f; do
            echo "### $f"
            echo ""
            echo '```yaml'
            cat "$f"
            echo '```'
            echo ""
        done
    fi

    # README
    if [ -f "README.md" ]; then
        echo "## README"
        echo ""
        cat README.md
        echo ""
    fi

} > "$OUTPUT"

LINES=$(wc -l < "$OUTPUT")
SIZE=$(du -h "$OUTPUT" | cut -f1)

echo "  ${GREEN}✓${RESET} $OUTPUT ($LINES lines, $SIZE)"
echo ""

# Generate compact version
COMPACT="${OUTPUT%.md}.compact.md"
{
    echo "# Codebase (compact): $(basename "$(pwd)")"
    echo ""

    find . -name "*.cs" -not -path '*/bin/*' -not -path '*/obj/*' -not -path './.git/*' \
        -not -path '*/artifacts/*' | sort | while read -r f; do
        # Strip comments, blank lines, using directives
        sed -e '/^\/\/\//d' -e '/^using /d' -e '/^$/d' -e '/^[[:space:]]*$/d' "$f" 2>/dev/null | head -200
        echo ""
        echo "---"
        echo ""
    done
} > "$COMPACT"

COMPACT_LINES=$(wc -l < "$COMPACT")
COMPACT_SIZE=$(du -h "$COMPACT" | cut -f1)
echo "  ${GREEN}✓${RESET} $COMPACT ($COMPACT_LINES lines, $COMPACT_SIZE)"
echo ""
