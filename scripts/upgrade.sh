#!/usr/bin/env bash
# Usage: bash scripts/upgrade.sh [--dry-run]
# Upgrades the template infrastructure in a generated package to the latest version.
# Preserves: Runtime/**, Tests/**, Editor/**, package.json, README.md, LICENSE, CHANGELOG.md
# Updates:   scripts/**, .github/workflows/**, Directory.Build.props, global.json
set -euo pipefail

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

TEMPLATE_URL="https://github.com/IAFahim/UnityUPMPackageTemplate.git"
TMP=$(mktemp -d)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# Confirm this is a generated package, not a raw template
if [ -f "__PACKAGE__/Runtime/__PLACEHOLDER__.cs" ]; then
    echo "This is the raw template. Upgrade is for generated packages only."
    exit 1
fi

# Get package identity from package.json
PKG_NAME=$(python3 -c "import json; print(json.load(open('package.json'))['name'])")
PKG_VER=$(python3 -c "import json; print(json.load(open('package.json'))['version'])")

echo ""
echo "  Upgrading $PKG_NAME v$PKG_VER template infrastructure..."
echo ""

# Clone latest template
git clone --depth 1 "$TEMPLATE_URL" "$TMP/template" 2>/dev/null

# Files to upgrade (infrastructure only — never touch source)
UPGRADE_DIRS=(
    ".github/workflows"
    "scripts"
)

UPGRADE_FILES=(
    "Directory.Build.props"
    "global.json"
    ".editorconfig"
    ".gitattributes"
)

# Preserve user values
AUTHOR=$(python3 -c "import json; d=json.load(open('package.json')); print(d.get('author',{}).get('name','') if isinstance(d.get('author'),dict) else d.get('author',''))")
DISPLAY=$(python3 -c "import json; print(json.load(open('package.json'))['displayName'])")
NAMESPACE=$(grep -r 'rootNamespace' --include='*.asmdef' . 2>/dev/null | head -1 | grep -oP '"rootNamespace": "\K[^"]+' || echo "")
UNITY_MIN=$(python3 -c "import json; print(json.load(open('package.json')).get('unity','2022.3'))")
GH_OWNER=$(git remote get-url origin 2>/dev/null | grep -oP 'github\.com[:/]\K[^/]+' || echo "")

CHANGED=0

for dir in "${UPGRADE_DIRS[@]}"; do
    src="$TMP/template/$dir"
    dst="$ROOT/$dir"
    if [ ! -d "$src" ]; then continue; fi
    if $DRY_RUN; then
        echo "  [DRY RUN] Would update: $dir/"
    else
        mkdir -p "$dst"
        # For each file in src, apply token replacement and copy
        find "$src" -type f | while read -r f; do
            rel="${f#$src/}"
            target="$dst/$rel"
            mkdir -p "$(dirname "$target")"
            sed \
                -e "s/__PACKAGE__/$(printf '%s' "$PKG_NAME" | sed 's/[\\/&]/\\&/g')/g" \
                -e "s/__NAMESPACE__/$(printf '%s' "$NAMESPACE" | sed 's/[\\/&]/\\&/g')/g" \
                -e "s/__DISPLAY__/$(printf '%s' "$DISPLAY" | sed 's/[\\/&]/\\&/g')/g" \
                -e "s/__AUTHOR__/$(printf '%s' "$AUTHOR" | sed 's/[\\/&]/\\&/g')/g" \
                -e "s/__UNITY_MIN__/$(printf '%s' "$UNITY_MIN" | sed 's/[\\/&]/\\&/g')/g" \
                "$f" > "$target"
            CHANGED=$((CHANGED + 1))
        done
        echo "  ✓ Updated: $dir/"
    fi
done

for file in "${UPGRADE_FILES[@]}"; do
    src="$TMP/template/$file"
    dst="$ROOT/$file"
    if [ ! -f "$src" ]; then continue; fi
    if $DRY_RUN; then
        echo "  [DRY RUN] Would update: $file"
    else
        # Only overwrite if newer (check content diff)
        if ! diff -q "$src" "$dst" >/dev/null 2>&1; then
            cp "$src" "$dst"
            echo "  ✓ Updated: $file"
            CHANGED=$((CHANGED + 1))
        else
            echo "  ✓ Up to date: $file"
        fi
    fi
done

if $DRY_RUN; then
    echo ""
    echo "  Dry run complete. Run without --dry-run to apply."
else
    echo ""
    echo "  Upgrade complete. Review changes: git diff"
    echo "  Test: bash scripts/smoke.sh"
    echo "  Commit: git add -A && git commit -m 'chore: upgrade template infrastructure'"
fi
echo ""
