#!/usr/bin/env bash
# Usage: bash scripts/publish-openupm.sh
# Generates the OpenUPM registration PR content and opens the browser.
set -euo pipefail

PKG_NAME=$(python3 -c "import json; print(json.load(open('package.json'))['name'])" 2>/dev/null)
PKG_DISPLAY=$(python3 -c "import json; print(json.load(open('package.json'))['displayName'])" 2>/dev/null)
PKG_VER=$(python3 -c "import json; print(json.load(open('package.json'))['version'])" 2>/dev/null)
GH_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//')

if [ -z "$PKG_NAME" ] || [ -z "$GH_URL" ]; then
    echo "Run from a generated package directory with a git remote set."
    exit 1
fi

# Validate not a placeholder
if echo "$PKG_NAME" | grep -q '__'; then
    echo "FAIL: package.json still has placeholders. Run setup.sh first."
    exit 1
fi

# Generate the openupm package entry
ENTRY_FILE="artifacts/openupm-entry.yml"
mkdir -p artifacts
cat > "$ENTRY_FILE" <<YAML
# OpenUPM package entry — submit this file as a PR to:
# https://github.com/openupm/openupm/tree/master/data/packages
# File path: data/packages/${PKG_NAME}.yml

name: $PKG_NAME
displayName: $PKG_DISPLAY
description: $(python3 -c "import json; print(json.load(open('package.json')).get('description',''))" 2>/dev/null)
repoUrl: $GH_URL
parentRepoUrl:
licenseSpdxId: $(python3 -c "import json; print(json.load(open('package.json')).get('license','MIT'))" 2>/dev/null)
licenseName:
topics:
  - unity
  - upm
hunter:
image:
readme: README.md
minScope:
YAML

echo ""
echo "  OpenUPM entry generated: $ENTRY_FILE"
echo ""
echo "  Next steps:"
echo "  1. Review: cat $ENTRY_FILE"
echo "  2. Fork https://github.com/openupm/openupm"
echo "  3. Copy $ENTRY_FILE to data/packages/$PKG_NAME.yml in your fork"
echo "  4. Submit a PR"
echo ""
echo "  After the PR merges, every 'git tag v*' triggers automatic indexing."
echo ""

# Open browser if possible
if command -v open >/dev/null 2>&1; then
    open "https://github.com/openupm/openupm/fork"
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "https://github.com/openupm/openupm/fork"
fi
