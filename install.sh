#!/usr/bin/env bash
# ┌───────────────────────────────────────────────────────────────────┐
# │                                                                   │
# │   unity-package create                                            │
# │                                                                   │
# │   One command. Your Unity package. Done.                          │
# │                                                                   │
# │   Usage:                                                          │
# │     bash <(curl -sL YOUR_RAW_URL/install.sh)                      │
# │     bash <(curl -sL YOUR_RAW_URL/install.sh) my-folder            │
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

# ── Step 1: Folder name ─────────────────────────────────────────

if [ -z "$FOLDER_NAME" ]; then
    read -rp "  ${BOLD}Folder name${RESET} (e.g. grid-pathfinding): " FOLDER_NAME
fi

if [ -z "$FOLDER_NAME" ]; then
    echo "  ${BOLD}Need a folder name. Aborting.${RESET}"
    exit 1
fi

if [ -d "$FOLDER_NAME" ]; then
    echo "  ${BOLD}Folder '$FOLDER_NAME' already exists. Aborting.${RESET}"
    exit 1
fi

# ── Step 2: Package details ─────────────────────────────────────

echo ""
echo "  ${DIM}── Package Identity ──────────────────────────────────${RESET}"
echo ""
read -rp "  ${BOLD}Package ID${RESET} (e.g. com.bovinelabs.grid.pathfinding): " PACKAGE_ID
read -rp "  ${BOLD}Display name${RESET} (e.g. Grid Pathfinding): " DISPLAY_NAME
read -rp "  ${BOLD}Author${RESET} (e.g. Vex Interactive): " AUTHOR
read -rp "  ${BOLD}C# namespace${RESET} [auto]: " NAMESPACE

if [ -z "$PACKAGE_ID" ] || [ -z "$DISPLAY_NAME" ] || [ -z "$AUTHOR" ]; then
    echo "  ${BOLD}Package ID, display name, and author are required. Aborting.${RESET}"
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
read -rp "  ${BOLD}Create this package?${RESET} [Y/n] " CONFIRM

if [ "$CONFIRM" = "n" ] || [ "$CONFIRM" = "N" ]; then
    echo "  Aborted."
    exit 0
fi

# ── Step 3: Clone template ──────────────────────────────────────

echo ""
echo "  ${GREEN}►${RESET} Cloning template..."
git clone --depth 1 "$TEMPLATE_REPO" "$FOLDER_NAME" 2>/dev/null

cd "$FOLDER_NAME"

# Remove template's own git history — this is a fresh start
rm -rf .git

# ── Step 4: Rename folders ──────────────────────────────────────

echo "  ${GREEN}►${RESET} Setting up package structure..."

[ -d "__PACKAGE__.Runtime" ] && mv "__PACKAGE__.Runtime" "$PACKAGE_ID.Runtime"
[ -d "__PACKAGE__.Tests" ] && mv "__PACKAGE__.Tests" "$PACKAGE_ID.Tests"
[ -d "src/__PACKAGE__" ] && mv "src/__PACKAGE__" "src/$PACKAGE_ID"
[ -d "tests/__PACKAGE__.Tests" ] && mv "tests/__PACKAGE__.Tests" "tests/$PACKAGE_ID.Tests"
[ -d "benchmarks/__PACKAGE__.Benchmarks" ] && mv "benchmarks/__PACKAGE__.Benchmarks" "benchmarks/$PACKAGE_ID.Benchmarks"
[ -f "__PACKAGE__.slnx" ] && mv "__PACKAGE__.slnx" "$PACKAGE_ID.slnx"

# ── Step 5: Rename files ────────────────────────────────────────

find . -name "__PACKAGE__*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f")
    base=$(basename "$f")
    newname=$(echo "$base" | sed "s/__PACKAGE__/$PACKAGE_ID/g")
    [ "$base" != "$newname" ] && mv "$f" "$dir/$newname"
done

# ── Step 6: Replace all placeholders ────────────────────────────

echo "  ${GREEN}►${RESET} Personalizing files..."

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

# ── Step 7: Clean placeholders ──────────────────────────────────

find . -name "__PLACEHOLDER__*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f")
    base=$(basename "$f")
    newname=$(echo "$base" | sed "s/__PLACEHOLDER__/Template/g")
    mv "$f" "$dir/$newname"
done

# ── Step 8: Remove template-only files ──────────────────────────

rm -f setup.sh        # setup.sh is for when you clone manually
rm -f install.sh      # this script (we're running from memory)

chmod +x scripts/smoke.sh

# ── Step 9: Verify build ────────────────────────────────────────

echo "  ${GREEN}►${RESET} Restoring packages..."
dotnet restore "$PACKAGE_ID.slnx" >/dev/null 2>&1

echo "  ${GREEN}►${RESET} Building..."
dotnet build "$PACKAGE_ID.slnx" -c Release --no-restore >/dev/null 2>&1

echo "  ${GREEN}►${RESET} Running tests..."
TEST_OUTPUT=$(dotnet test "$PACKAGE_ID.slnx" -c Release --no-build 2>&1)
if echo "$TEST_OUTPUT" | grep -q "Passed!"; then
    PASSED=$(echo "$TEST_OUTPUT" | grep -oP 'Passed:\s*\K\d+')
    echo "  ${GREEN}✓${RESET} ${BOLD}${PASSED:-0} tests pass${RESET}"
else
    echo "  ${DIM}⚠ Tests didn't run (expected for fresh template)${RESET}"
fi

# ── Step 10: Git init ───────────────────────────────────────────

echo "  ${GREEN}►${RESET} Initializing git..."
git init >/dev/null 2>&1
git add -A >/dev/null 2>&1
git commit -m "init: $DISPLAY_NAME" >/dev/null 2>&1
git branch -M main >/dev/null 2>&1

# ── Step 11: GitHub? ────────────────────────────────────────────

echo ""
GH_AVAILABLE=false
command -v gh >/dev/null 2>&1 && GH_AVAILABLE=true

if [ "$GH_AVAILABLE" = true ]; then
    read -rp "  ${BOLD}Push to GitHub now?${RESET} [Y/n] " PUSH_GH
    if [ "$PUSH_GH" != "n" ] && [ "$PUSH_GH" != "N" ]; then
        GH_USER=$(gh api user -q .login 2>/dev/null || echo "")
        read -rp "  ${BOLD}GitHub repo name${RESET} [$PACKAGE_ID]: " GH_REPO
        GH_REPO="${GH_REPO:-$PACKAGE_ID}"

        read -rp "  ${BOLD}Public or private?${RESET} [public/private]: " GH_VIS
        GH_VIS="${GH_VIS:-public}"

        echo "  ${GREEN}►${RESET} Creating GitHub repo..."
        gh repo create "$GH_USER/$GH_REPO" --${GH_VIS} --source=. --push \
            --description "$DISPLAY_NAME" 2>&1 | head -1

        echo ""
        echo "  ${GREEN}✓${RESET} ${BOLD}Pushed to GitHub${RESET}"
        echo "  ${DIM}https://github.com/$GH_USER/$GH_REPO${RESET}"
    fi
fi

# ── Done ────────────────────────────────────────────────────────

echo ""
echo "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "  ${BOLD}  $DISPLAY_NAME is ready.${RESET}"
echo "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "  ${BOLD}Edit:${RESET}    cd $FOLDER_NAME && vim $PACKAGE_ID.Runtime/Template.cs"
echo "  ${BOLD}Test:${RESET}    dotnet test -c Release"
echo "  ${BOLD}Smoke:${RESET}   bash scripts/smoke.sh"
echo "  ${BOLD}Unity:${RESET}   Package Manager → Add from git URL"
echo ""
