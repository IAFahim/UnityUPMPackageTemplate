#!/usr/bin/env bash
# ── Bump package version everywhere ─────────────────────────────
set -euo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' RESET=$'\033[0m'

BUMP="${1:-}"

if [ -z "$BUMP" ]; then
    echo "  Usage: ./scripts/version.sh <version|patch|minor|major>"
    echo "  Example: ./scripts/version.sh 0.2.0"
    echo "           ./scripts/version.sh patch"
    exit 1
fi

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

OLD_VERSION=$(python3 -c "import json; print(json.load(open('package.json'))['version'])" 2>/dev/null || echo "0.0.0")

if [[ "$BUMP" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    NEW_VERSION="$BUMP"
else
    # Calculate new version
    IFS='.' read -r major minor patch <<< "${OLD_VERSION%%-*}"
    case "$BUMP" in
        major) NEW_VERSION="$((major + 1)).0.0" ;;
        minor) NEW_VERSION="$major.$((minor + 1)).0" ;;
        patch) NEW_VERSION="$major.$minor.$((patch + 1))" ;;
        *) echo "  ${RED}✗${RESET} Invalid bump type: $BUMP"; exit 1 ;;
    esac
fi

# Update package.json
python3 -c "
import json
with open('package.json') as f: d = json.load(f)
d['version'] = '$NEW_VERSION'
with open('package.json', 'w') as f: json.dump(d, f, indent=2)
"
echo "  ${GREEN}✓${RESET} package.json: $OLD_VERSION → $NEW_VERSION"

# Update CHANGELOG.md if it exists
if [ -f "CHANGELOG.md" ]; then
    DATE=$(date +%Y-%m-%d)
    if grep -q "## \[$NEW_VERSION\]" CHANGELOG.md; then
        echo "  ${YELLOW}⚠${RESET} CHANGELOG.md: $NEW_VERSION section already exists"
    else
        python3 -c "
import sys
try:
    with open('CHANGELOG.md', 'r') as f: lines = f.readlines()
    for i, line in enumerate(lines):
        if line.startswith('## '):
            lines.insert(i, f'## [$NEW_VERSION] - $DATE\n\n- \n\n')
            break
    with open('CHANGELOG.md', 'w') as f: f.writelines(lines)
except Exception as e:
    sys.exit(1)
"
        echo "  ${GREEN}✓${RESET} CHANGELOG.md: added $NEW_VERSION section"
    fi
fi

echo ""
echo "  ${BOLD}Bumped to $NEW_VERSION${RESET}"
echo "  Next steps:"
echo "    ${DIM}git add -A && git commit -m 'chore: release $NEW_VERSION'${RESET}"
echo "    ${DIM}git tag v$NEW_VERSION && git push origin main --tags${RESET}"
echo ""

if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "  ${DIM}Generating AI changelog...${RESET}"
    bash scripts/ai-changelog.sh "$NEW_VERSION" --apply 2>/dev/null || \
        bash scripts/changelog-draft.sh "$NEW_VERSION" --apply 2>/dev/null || true
else
    echo "  ${DIM}Drafting changelog...${RESET}"
    bash scripts/changelog-draft.sh "$NEW_VERSION" --apply 2>/dev/null || true
fi
