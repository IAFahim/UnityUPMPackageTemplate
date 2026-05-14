#!/usr/bin/env bash
# ┌─────────────────────────────────────────────────────────────┐
# │  Unity Package Template Setup                               │
# │  Transforms this template into your personalized package.   │
# │                                                             │
# │  Usage:                                                     │
# │    ./setup.sh                                               │
# │    ./setup.sh <package-id> <display> "<author>" <namespace>│
# │                                                             │
# │  If run with no args, walks you through it interactively.   │
# └─────────────────────────────────────────────────────────────┘
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
    echo "  ╔═══════════════════════════════════════════════╗"
    echo "  ║     Unity Package Template Setup              ║"
    echo "  ╚═══════════════════════════════════════════════╝"
    echo ""
    read -rp "  Package ID (e.g. com.bovinelabs.grid.pathfinding): " PACKAGE_ID
    read -rp "  Display name (e.g. Grid Pathfinding): " DISPLAY_NAME
    read -rp "  Author (e.g. Vex Interactive): " AUTHOR
    read -rp "  C# namespace [auto-derived]: " NAMESPACE

    if [ -z "$NAMESPACE" ]; then
        NAMESPACE=$(echo "$PACKAGE_ID" | awk -F'.' '{
            for(i=2;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)) substr($i,2), (i<NF?".":"")
        }')
    fi

    echo ""
    echo "  Package ID:  $PACKAGE_ID"
    echo "  Display:     $DISPLAY_NAME"
    echo "  Author:      $AUTHOR"
    echo "  Namespace:   $NAMESPACE"
    echo ""
    read -rp "  Looks good? [Y/n] " CONFIRM
    if [ "$CONFIRM" = "n" ] || [ "$CONFIRM" = "N" ]; then
        echo "  Aborted."
        exit 1
    fi
fi

DESCRIPTION="$DISPLAY_NAME"
YEAR=$(date +%Y)

echo ""
echo "  Setting up $DISPLAY_NAME..."
echo ""

# ── 1. Rename folders ──────────────────────────────────────────

echo "  [1/5] Renaming folders..."
[ -d "__PACKAGE__.Runtime" ] && mv "__PACKAGE__.Runtime" "$PACKAGE_ID.Runtime"
[ -d "__PACKAGE__.Tests" ] && mv "__PACKAGE__.Tests" "$PACKAGE_ID.Tests"
[ -d "src/__PACKAGE__" ] && mv "src/__PACKAGE__" "src/$PACKAGE_ID"
[ -d "tests/__PACKAGE__.Tests" ] && mv "tests/__PACKAGE__.Tests" "tests/$PACKAGE_ID.Tests"
[ -d "benchmarks/__PACKAGE__.Benchmarks" ] && mv "benchmarks/__PACKAGE__.Benchmarks" "benchmarks/$PACKAGE_ID.Benchmarks"
[ -f "__PACKAGE__.slnx" ] && mv "__PACKAGE__.slnx" "$PACKAGE_ID.slnx"

# ── 2. Rename files ────────────────────────────────────────────

echo "  [2/5] Renaming files..."
find . -name "__PACKAGE__*" -not -path "*/.*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f")
    base=$(basename "$f")
    newname=$(echo "$base" | sed "s/__PACKAGE__/$PACKAGE_ID/g")
    [ "$base" != "$newname" ] && mv "$f" "$dir/$newname"
done

# ── 3. Replace all placeholders in text files ──────────────────

echo "  [3/5] Personalizing source files..."
find . -type f \( -name "*.cs" -o -name "*.csproj" -o -name "*.slnx" -o -name "*.asmdef" \
    -o -name "*.json" -o -name "*.yml" -o -name "*.md" -o -name "*.sh" -o -name "*.ps1" \
    -o -name "LICENSE" \) \
    -not -path "*/bin/*" -not -path "*/obj/*" -not -path "*/.git/*" \
    -exec sed -i \
    -e "s/__PACKAGE__/$PACKAGE_ID/g" \
    -e "s/__NAMESPACE__/$NAMESPACE/g" \
    -e "s/__DISPLAY__/$DISPLAY_NAME/g" \
    -e "s/__DESCRIPTION__/$DESCRIPTION/g" \
    -e "s/__AUTHOR__/$AUTHOR/g" \
    -e "s/__YEAR__/$YEAR/g" \
    {} +

# ── 4. Rename placeholder source files ─────────────────────────

echo "  [4/5] Cleaning placeholders..."
find . -name "__PLACEHOLDER__*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f")
    base=$(basename "$f")
    # __PLACEHOLDER__.Tests.cs → Template.Tests.cs, __PLACEHOLDER__.cs → Template.cs
    newname=$(echo "$base" | sed "s/__PLACEHOLDER__/Template/g")
    mv "$f" "$dir/$newname"
done

# ── 5. Finalize ────────────────────────────────────────────────

chmod +x scripts/smoke.sh

echo "  [5/5] Self-destructing setup script..."
rm -- "$0"

echo ""
echo "  ✅ $DISPLAY_NAME is ready."
echo ""
echo "     Edit:   $PACKAGE_ID.Runtime/"
echo "     Test:   dotnet test -c Release"
echo "     Push:   git init && git add . && git commit -m 'init'"
echo ""
