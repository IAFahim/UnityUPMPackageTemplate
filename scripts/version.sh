#!/usr/bin/env bash
# ── Bump package version everywhere ─────────────────────────────
set -euo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' RESET=$'\033[0m'

VERSION="${1:-}"

if [ -z "$VERSION" ]; then
    echo "  Usage: ./scripts/version.sh <version>"
    echo "  Example: ./scripts/version.sh 0.2.0"
    exit 1
fi

# Validate semver
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    echo "  ${RED}✗${RESET} '$VERSION' is not valid semver (e.g. 0.2.0, 1.0.0-alpha.1)"
    exit 1
fi

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

# Update package.json
if [ -f "package.json" ]; then
    OLD=$(python3 -c "import json; print(json.load(open('package.json'))['version'])" 2>/dev/null || true)
    python3 -c "
import json
with open('package.json') as f: d = json.load(f)
d['version'] = '$VERSION'
with open('package.json', 'w') as f: json.dump(d, f, indent=2)
    "
    echo "  ${GREEN}✓${RESET} package.json: $OLD → $VERSION"
fi

# Update CHANGELOG.md if it exists
if [ -f "CHANGELOG.md" ]; then
    # Insert new section after the header
    sed -i "1,/^## /{s/^## .*/## [$VERSION] - $(date +%Y-%m-%d)\n\n- /}" CHANGELOG.md 2>/dev/null || true
    echo "  ${GREEN}✓${RESET} CHANGELOG.md: added $VERSION section"
fi

echo ""
echo "  ${BOLD}Bumped to $VERSION${RESET}"
echo "  Commit: git add -A && git commit -m 'release $VERSION'"
echo "  Tag:    git tag v$VERSION && git push --tags"
