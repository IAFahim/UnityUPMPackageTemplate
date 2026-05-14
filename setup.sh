#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Gather inputs ──────────────────────────────────────────────

if [ $# -ge 4 ]; then
    PACKAGE_ID="$1"
    DISPLAY_NAME="$2"
    AUTHOR="$3"
    NAMESPACE="$4"
elif [ $# -ge 3 ]; then
    PACKAGE_ID="$1"
    DISPLAY_NAME="$2"
    AUTHOR="$3"
    NAMESPACE=$(echo "$PACKAGE_ID" | awk -F'.' '{
        for(i=2;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)) substr($i,2), (i<NF?".":"")
    }')
else
    echo ""
    echo "  Unity Package Setup"
    echo ""
    read -rp "  Package ID (e.g. com.bovinelabs.grid.pathfinding): " PACKAGE_ID
    read -rp "  Display name (e.g. Grid Pathfinding): " DISPLAY_NAME
    read -rp "  Author (e.g. Vex Interactive): " AUTHOR
    read -rp "  C# namespace [auto]: " NAMESPACE

    if [ -z "$NAMESPACE" ]; then
        NAMESPACE=$(echo "$PACKAGE_ID" | awk -F'.' '{
            for(i=2;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)) substr($i,2), (i<NF?".":"")
        }')
    fi

    echo ""
    echo "  Package:  $PACKAGE_ID"
    echo "  Display:  $DISPLAY_NAME"
    echo "  Author:   $AUTHOR"
    echo "  Namespace: $NAMESPACE"
    echo ""
    read -rp "  Create? [Y/n] " CONFIRM
    if [ "$CONFIRM" = "n" ] || [ "$CONFIRM" = "N" ]; then exit 1; fi
fi

YEAR=$(date +%Y)
echo ""

# ── Rename folders ──────────────────────────────────────────────

echo "  Setting up..."
[ -d "__PACKAGE__.Runtime" ] && mv "__PACKAGE__.Runtime" "$PACKAGE_ID.Runtime"
[ -d "__PACKAGE__.Tests" ] && mv "__PACKAGE__.Tests" "$PACKAGE_ID.Tests"
[ -d "src/__PACKAGE__" ] && mv "src/__PACKAGE__" "src/$PACKAGE_ID"
[ -d "tests/__PACKAGE__.Tests" ] && mv "tests/__PACKAGE__.Tests" "tests/$PACKAGE_ID.Tests"
[ -d "benchmarks/__PACKAGE__.Benchmarks" ] && mv "benchmarks/__PACKAGE__.Benchmarks" "benchmarks/$PACKAGE_ID.Benchmarks"
[ -f "__PACKAGE__.slnx" ] && mv "__PACKAGE__.slnx" "$PACKAGE_ID.slnx"

# ── Rename files ────────────────────────────────────────────────

find . -name "__PACKAGE__*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f")
    base=$(basename "$f")
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
    dir=$(dirname "$f")
    base=$(basename "$f")
    newname=$(echo "$base" | sed "s/__PLACEHOLDER__/Template/g")
    mv "$f" "$dir/$newname"
done

# ── Erase all traces ────────────────────────────────────────────

chmod +x scripts/smoke.sh
rm -f AGENTS.md
rm -f CHANGELOG.md
rm -rf .github
rm -- "$0"

# Write a clean README
cat > README.md <<README
# $DISPLAY_NAME

> $DISPLAY_NAME

Build outside Unity. Ship as Unity package.

\`\`\`bash
dotnet test -c Release
git push
\`\`\`

## Installation

Add to your Unity project's \`Packages/manifest.json\`:

\`\`\`json
{
  "dependencies": {
    "$PACKAGE_ID": "https://github.com/$AUTHOR/$PACKAGE_ID.git"
  }
}
\`\`\`

Or Unity Editor → Package Manager → Add package from git URL.

## Requirements

- .NET 8 SDK (for development)
- Unity 2022.3+ (for runtime)

## License

MIT © $YEAR $AUTHOR
README

echo ""
echo "  Done."
echo ""
echo "    Edit:  $PACKAGE_ID.Runtime/"
echo "    Test:  dotnet test -c Release"
echo ""
