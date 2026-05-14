#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

# ── Helpers ─────────────────────────────────────────────────────

pascal() {
    echo "$1" | sed 's/[-_ ]\+/_/g' | awk -F'_' '{for(i=1;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)), substr($i,2)}'
}

package_to_namespace() {
    echo "$1" | awk -F'.' '{
        for(i=2;i<=NF;i++) {
            split($i, parts, /[-_]/)
            for(j=1;j<=length(parts);j++) {
                printf "%s%s", toupper(substr(parts[j],1,1)), substr(parts[j],2)
            }
            if(i<NF) printf "."
        }
    }'
}

validate_package_id() {
    [[ "$1" =~ ^[a-z][a-z0-9]*(\.[a-z][a-z0-9_-]*){2,}$ ]]
}

detect_author()   { git config --global user.name 2>/dev/null || gh api user -q .login 2>/dev/null || echo ""; }
detect_gh_owner() { gh api user -q .login 2>/dev/null || echo ""; }

# ── Gather inputs ───────────────────────────────────────────────

DEFAULT_AUTHOR=$(detect_author)
DEFAULT_GH=$(detect_gh_owner)
DERIVED_ID="" DERIVED_NS="" DERIVED_DISPLAY=""

# Derive from folder name if it looks like a package ID
FOLDER=$(basename "$(pwd)")
if [[ "$FOLDER" =~ ^[a-z]+(\.[a-z0-9_-]+){2,}$ ]]; then
    DERIVED_ID="$FOLDER"
    DERIVED_NS=$(package_to_namespace "$FOLDER")
    DERIVED_DISPLAY=$(pascal "$(echo "$FOLDER" | awk -F'.' '{print $NF}')")
fi

if [ $# -ge 4 ]; then
    PACKAGE_ID="$1"; DISPLAY_NAME="$2"; AUTHOR="$3"; NAMESPACE="$4"
elif [ $# -ge 3 ]; then
    PACKAGE_ID="$1"; DISPLAY_NAME="$2"; AUTHOR="$3"
    NAMESPACE=$(package_to_namespace "$PACKAGE_ID")
else
    echo ""

    # Package ID
    if [ -n "$DERIVED_ID" ]; then
        read -rp "  Package ID [$DERIVED_ID]: " PACKAGE_ID
        PACKAGE_ID="${PACKAGE_ID:-$DERIVED_ID}"
    else
        read -rp "  Package ID (e.g. com.bovinelabs.grid.pathfinding): " PACKAGE_ID
    fi

    # Display name
    if [ -n "$DERIVED_DISPLAY" ]; then
        read -rp "  Display name [$DERIVED_DISPLAY]: " DISPLAY_NAME
        DISPLAY_NAME="${DISPLAY_NAME:-$DERIVED_DISPLAY}"
    else
        read -rp "  Display name (e.g. Grid Pathfinding): " DISPLAY_NAME
    fi

    # Author
    if [ -n "$DEFAULT_AUTHOR" ]; then
        read -rp "  Author [$DEFAULT_AUTHOR]: " AUTHOR
        AUTHOR="${AUTHOR:-$DEFAULT_AUTHOR}"
    else
        read -rp "  Author (e.g. Vex Interactive): " AUTHOR
    fi

    # Namespace
    AUTO_NS=$(package_to_namespace "$PACKAGE_ID")
    read -rp "  C# namespace [$AUTO_NS]: " NAMESPACE
    NAMESPACE="${NAMESPACE:-$AUTO_NS}"

    echo ""
    echo "  Package:   $PACKAGE_ID"
    echo "  Display:   $DISPLAY_NAME"
    echo "  Author:    $AUTHOR"
    echo "  Namespace: $NAMESPACE"
    echo ""
    read -rp "  Create? [Y/n] " CONFIRM
    [[ "$CONFIRM" =~ ^[Nn] ]] && exit 1
fi

if ! validate_package_id "$PACKAGE_ID"; then
    echo "  Invalid package ID. Must be lowercase reverse-DNS." && exit 1
fi

YEAR=$(date +%Y)
GH_OWNER="${DEFAULT_GH:-$AUTHOR}"
echo ""

# ── Rename folders ──────────────────────────────────────────────

echo "  Setting up..."
[ -d "__PACKAGE__.Runtime" ]          && mv "__PACKAGE__.Runtime"          "$PACKAGE_ID.Runtime"
[ -d "__PACKAGE__.Tests" ]            && mv "__PACKAGE__.Tests"            "$PACKAGE_ID.Tests"
[ -d "src/__PACKAGE__" ]              && mv "src/__PACKAGE__"              "src/$PACKAGE_ID"
[ -d "tests/__PACKAGE__.Tests" ]      && mv "tests/__PACKAGE__.Tests"      "tests/$PACKAGE_ID.Tests"
[ -d "benchmarks/__PACKAGE__.Benchmarks" ] && mv "benchmarks/__PACKAGE__.Benchmarks" "benchmarks/$PACKAGE_ID.Benchmarks"
[ -f "__PACKAGE__.slnx" ]             && mv "__PACKAGE__.slnx"             "$PACKAGE_ID.slnx"

# ── Rename files ────────────────────────────────────────────────

find . -name "__PACKAGE__*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f"); base=$(basename "$f")
    newname=$(echo "$base" | sed "s/__PACKAGE__/$PACKAGE_ID/g")
    [ "$base" != "$newname" ] && mv "$f" "$dir/$newname"
done

# ── Personalize ─────────────────────────────────────────────────

find . -type f \( -name "*.cs" -o -name "*.csproj" -o -name "*.slnx" -o -name "*.asmdef" \
    -o -name "*.json" -o -name "*.yml" -o -name "*.md" -o -name "*.sh" -o -name "*.ps1" \
    -o -name "LICENSE" \) \
    -not -path "*/bin/*" -not -path "*/obj/*" -not -path "*/.git/*" \
    -exec sed -i \
    -e "s/__PACKAGE__/$PACKAGE_ID/g" \
    -e "s/__NAMESPACE__/$NAMESPACE/g" \
    -e "s/__DISPLAY__/$DISPLAY_NAME/g" \
    -e "s/__DESCRIPTION__/$DISPLAY_NAME/g" \
    -e "s/__AUTHOR__/$AUTHOR/g" \
    -e "s/__YEAR__/$YEAR/g" \
    {} +

# ── Clean placeholders ──────────────────────────────────────────

find . -name "__PLACEHOLDER__*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f"); base=$(basename "$f")
    mv "$f" "$dir/$(echo "$base" | sed 's/__PLACEHOLDER__/Template/')"
done

# ── Erase all traces ────────────────────────────────────────────

chmod +x scripts/smoke.sh
rm -f AGENTS.md CHANGELOG.md install.sh
# Keep .github/ — CI is essential
rm -- "$0"

# Clean README
BADGE_URL="https://github.com/$GH_OWNER/$PACKAGE_ID/actions/workflows/ci.yml/badge.svg"
cat > README.md <<README
# $DISPLAY_NAME

[![CI]($BADGE_URL)](https://github.com/$GH_OWNER/$PACKAGE_ID/actions)

> $DISPLAY_NAME

**Build outside Unity. Ship as Unity package.**

\`\`\`bash
dotnet test -c Release
git push
\`\`\`

## Install

Add to \`Packages/manifest.json\`:

\`\`\`json
"$PACKAGE_ID": "https://github.com/$GH_OWNER/$PACKAGE_ID.git"
\`\`\`

Or Unity → Package Manager → Add from git URL.

## Dev

\`\`\`bash
dotnet restore
dotnet test -c Release
\`\`\`

Source: \`$PACKAGE_ID.Runtime/\`  Tests: \`$PACKAGE_ID.Tests/\`

MIT © $YEAR $AUTHOR
README

echo ""
echo "  Done."
echo ""
echo "    Edit:  $PACKAGE_ID.Runtime/"
echo "    Test:  dotnet test -c Release"
echo ""
