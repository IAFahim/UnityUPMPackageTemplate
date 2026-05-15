#!/usr/bin/env bash
# ── Draft changelog from git history ────────────────────────────
set -uo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RESET=$'\033[0m'

VERSION="${1:-}"
APPLY="${2:-}"

if [ -z "$VERSION" ]; then
    # Try to read from package.json
    VERSION=$(python3 -c "import json; print(json.load(open('package.json'))['version'])" 2>/dev/null || true)
fi

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> [--apply]"
    exit 1
fi

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

echo ""
echo "  ${BOLD}Drafting changelog for v$VERSION...${RESET}"
echo ""

# Get last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -n "$LAST_TAG" ]; then
    RANGE="$LAST_TAG..HEAD"
    echo "  Since: $LAST_TAG"
else
    RANGE="HEAD"
    echo "  Since: beginning"
fi

echo ""

# Categorize commits
ADDED=""
CHANGED=""
FIXED=""
REMOVED=""
OTHER=""

while IFS= read -r line; do
    msg=$(echo "$line" | sed 's/^[a-f0-9]* //')
    hash=$(echo "$line" | awk '{print $1}')

    case "$msg" in
        feat:*|add:*|Added:*|added:*) ADDED="$ADDED\n- $msg" ;;
        fix:*|Fix:*|fix:*|hotfix:*)   FIXED="$FIXED\n- $msg" ;;
        change:*|Change:*|refactor:*|update:*|Update:*) CHANGED="$CHANGED\n- $msg" ;;
        remove:*|Remove:*|delete:*|Delete:*) REMOVED="$REMOVED\n- $msg" ;;
        release*|init*|bump*|Merge*) ;; # skip noise
        *) OTHER="$OTHER\n- $msg" ;;
    esac
done < <(git log --oneline $RANGE 2>/dev/null || echo "")

# Build draft
DRAFT=""
DRAFT+="## [$VERSION] - $(date +%Y-%m-%d)\n\n"

if [ -n "$ADDED" ]; then
    DRAFT+="### Added\n$(echo -e "$ADDED")\n\n"
fi
if [ -n "$CHANGED" ]; then
    DRAFT+="### Changed\n$(echo -e "$CHANGED")\n\n"
fi
if [ -n "$FIXED" ]; then
    DRAFT+="### Fixed\n$(echo -e "$FIXED")\n\n"
fi
if [ -n "$REMOVED" ]; then
    DRAFT+="### Removed\n$(echo -e "$REMOVED")\n\n"
fi
if [ -n "$OTHER" ]; then
    DRAFT+="### Other\n$(echo -e "$OTHER")\n\n"
fi

mkdir -p artifacts/release
echo -e "$DRAFT" > artifacts/release/CHANGELOG.draft.md

echo -e "$DRAFT"

if [ "$APPLY" = "--apply" ]; then
    # Insert into CHANGELOG.md after header
    if [ -f "CHANGELOG.md" ]; then
        # Create temp with new section + old content
        {
            echo -e "$DRAFT"
            tail -n +3 CHANGELOG.md
        } > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
        echo ""
        echo "  ${GREEN}✓${RESET} CHANGELOG.md updated"
    else
        echo -e "$DRAFT" > CHANGELOG.md
        echo ""
        echo "  ${GREEN}✓${RESET} CHANGELOG.md created"
    fi
else
    echo ""
    echo "  Draft saved to artifacts/release/CHANGELOG.draft.md"
    echo "  Apply with: $0 $VERSION --apply"
fi

echo ""
