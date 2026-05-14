#!/usr/bin/env bash
# ┌───────────────────────────────────────────────────────────────────┐
# │                                                                   │
# │   Unity UPM Package Creator                                       │
# │                                                                   │
# │   One command. Your Unity package. Done.                          │
# │                                                                   │
# │   Usage:                                                          │
# │     bash <(curl -sL INSTALL_URL/install.sh)                       │
# │     bash <(curl -sL INSTALL_URL/install.sh) my-folder             │
# │                                                                   │
# └───────────────────────────────────────────────────────────────────┘
set -euo pipefail

TEMPLATE_REPO="https://github.com/IAFahim/UnityUPMPackageTemplate.git"
FOLDER_NAME="${1:-}"

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
CYAN='\033[36m'
RESET='\033[0m'

echo ""
echo "  ${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo "  ${BOLD}║                                                      ║${RESET}"
echo "  ${BOLD}║   ${CYAN}Unity UPM Package Creator${RESET}${BOLD}                          ║${RESET}"
echo "  ${BOLD}║   ${DIM}Build outside Unity. Ship as Unity package.${RESET}${BOLD}       ║${RESET}"
echo "  ${BOLD}║                                                      ║${RESET}"
echo "  ${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""

# ── Gather inputs ───────────────────────────────────────────────

if [ -z "$FOLDER_NAME" ]; then
    read -rp "  ${BOLD}Folder name${RESET} (e.g. grid-pathfinding): " FOLDER_NAME
fi

if [ -z "$FOLDER_NAME" ]; then
    echo "  Need a folder name. Aborting."
    exit 1
fi

if [ -d "$FOLDER_NAME" ]; then
    echo "  Folder '$FOLDER_NAME' already exists. Aborting."
    exit 1
fi

echo ""
echo "  ${DIM}── Package Identity ──────────────────────────────────${RESET}"
echo ""
read -rp "  ${BOLD}Package ID${RESET} (e.g. com.bovinelabs.grid.pathfinding): " PACKAGE_ID
read -rp "  ${BOLD}Display name${RESET} (e.g. Grid Pathfinding): " DISPLAY_NAME
read -rp "  ${BOLD}Author${RESET} (e.g. Vex Interactive): " AUTHOR
read -rp "  ${BOLD}C# namespace${RESET} [auto]: " NAMESPACE

if [ -z "$PACKAGE_ID" ] || [ -z "$DISPLAY_NAME" ] || [ -z "$AUTHOR" ]; then
    echo "  Package ID, display name, and author are required. Aborting."
    exit 1
fi

if [ -z "$NAMESPACE" ]; then
    NAMESPACE=$(echo "$PACKAGE_ID" | awk -F'.' '{
        for(i=2;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)) substr($i,2), (i<NF?".":"")
    }')
fi

YEAR=$(date +%Y)

echo ""
echo "  ${DIM}──────────────────────────────────────────────────────${RESET}"
echo "  ${BOLD}Package:${RESET}   $PACKAGE_ID"
echo "  ${BOLD}Display:${RESET}    $DISPLAY_NAME"
echo "  ${BOLD}Author:${RESET}     $AUTHOR"
echo "  ${BOLD}Namespace:${RESET}  $NAMESPACE"
echo "  ${BOLD}Folder:${RESET}     $FOLDER_NAME"
echo "  ${DIM}──────────────────────────────────────────────────────${RESET}"
echo ""
read -rp "  ${BOLD}Create?${RESET} [Y/n] " CONFIRM

if [ "$CONFIRM" = "n" ] || [ "$CONFIRM" = "N" ]; then
    echo "  Aborted."
    exit 0
fi

# ── Clone ───────────────────────────────────────────────────────

echo ""
echo "  ${GREEN}►${RESET} Cloning..."
git clone --depth 1 "$TEMPLATE_REPO" "$FOLDER_NAME" 2>/dev/null
cd "$FOLDER_NAME"
rm -rf .git

# ── Rename folders ──────────────────────────────────────────────

echo "  ${GREEN}►${RESET} Building structure..."
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

echo "  ${GREEN}►${RESET} Personalizing..."
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

# ── Clean placeholder files ─────────────────────────────────────

find . -name "__PLACEHOLDER__*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f")
    base=$(basename "$f")
    newname=$(echo "$base" | sed "s/__PLACEHOLDER__/Template/g")
    mv "$f" "$dir/$newname"
done

# ── Erase all traces of the template ────────────────────────────

echo "  ${GREEN}►${RESET} Cleaning up..."
rm -f "$OLDPWD/$FOLDER_NAME/setup.sh" 2>/dev/null || true
rm -f setup.sh 2>/dev/null || true
rm -f install.sh 2>/dev/null || true
rm -f AGENTS.md 2>/dev/null || true
rm -f CHANGELOG.md 2>/dev/null || true
rm -rf .github 2>/dev/null || true
chmod +x scripts/smoke.sh

# Write a clean README — no template references
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

# ── Verify ──────────────────────────────────────────────────────

echo "  ${GREEN}►${RESET} Restoring..."
dotnet restore "$PACKAGE_ID.slnx" >/dev/null 2>&1

echo "  ${GREEN}►${RESET} Building..."
dotnet build "$PACKAGE_ID.slnx" -c Release --no-restore >/dev/null 2>&1

echo "  ${GREEN}►${RESET} Testing..."
TEST_OUTPUT=$(dotnet test "$PACKAGE_ID.slnx" -c Release --no-build 2>&1)
if echo "$TEST_OUTPUT" | grep -q "Passed!"; then
    PASSED=$(echo "$TEST_OUTPUT" | grep -oP 'Passed:\s*\K\d+')
    echo "  ${GREEN}✓${RESET} ${BOLD}${PASSED:-0} tests pass${RESET}"
fi

# ── Git init ────────────────────────────────────────────────────

echo "  ${GREEN}►${RESET} Initializing..."
git init >/dev/null 2>&1
git add -A >/dev/null 2>&1
git commit -m "init" >/dev/null 2>&1
git branch -M main >/dev/null 2>&1

# ── GitHub ──────────────────────────────────────────────────────

echo ""
if command -v gh >/dev/null 2>&1; then
    read -rp "  ${BOLD}Push to GitHub?${RESET} [Y/n] " PUSH_GH
    if [ "$PUSH_GH" != "n" ] && [ "$PUSH_GH" != "N" ]; then
        GH_USER=$(gh api user -q .login 2>/dev/null || echo "")
        read -rp "  ${BOLD}Repo name${RESET} [$PACKAGE_ID]: " GH_REPO
        GH_REPO="${GH_REPO:-$PACKAGE_ID}"
        read -rp "  ${BOLD}Visibility${RESET} [public/private]: " GH_VIS
        GH_VIS="${GH_VIS:-public}"

        echo "  ${GREEN}►${RESET} Pushing..."
        gh repo create "$GH_USER/$GH_REPO" --${GH_VIS} --source=. --push \
            --description "$DISPLAY_NAME" 2>&1 | head -1
        echo "  ${GREEN}✓${RESET} ${BOLD}github.com/$GH_USER/$GH_REPO${RESET}"
    fi
fi

# ── Done ────────────────────────────────────────────────────────

echo ""
echo "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "  ${BOLD}  $DISPLAY_NAME is ready.${RESET}"
echo "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "  ${BOLD}Edit:${RESET}    $PACKAGE_ID.Runtime/"
echo "  ${BOLD}Test:${RESET}    dotnet test -c Release"
echo "  ${BOLD}Unity:${RESET}   Package Manager → Add from git URL"
echo ""
