#!/usr/bin/env bash
# ┌───────────────────────────────────────────────────────────────────┐
# │                                                                   │
# │   unity-package create                                            │
# │                                                                   │
# │   One command. Your Unity package. Done.                          │
# │                                                                   │
# │   bash <(curl -sL INSTALL_URL/install.sh)                         │
# │   bash <(curl -sL INSTALL_URL/install.sh) my-folder               │
# │                                                                   │
# └───────────────────────────────────────────────────────────────────┘
set -euo pipefail

TEMPLATE_REPO="https://github.com/IAFahim/UnityUPMPackageTemplate.git"
FOLDER_NAME="${1:-}"

BOLD=$'\033[1m' DIM=$'\033[2m' GREEN=$'\033[32m' CYAN=$'\033[36m' YELLOW=$'\033[33m' RED=$'\033[31m' RESET=$'\033[0m'

# ── Helpers ─────────────────────────────────────────────────────

# Pascal-case a string: "grid-pathfinding" → "GridPathfinding"
pascal() {
    echo "$1" | sed 's/[-_ ]\+/_/g' | awk -F'_' '{for(i=1;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)), substr($i,2)}'
}

# Convert com.owner.package-name → Owner.PackageName
package_to_namespace() {
    echo "$1" | awk -F'.' '{
        for(i=2;i<=NF;i++) {
            split($i, parts, /[-_]/)
            for(j=1;j<=length(parts);j++) {
                printf "%s%s", toupper(substr(parts[j],1,1)), substr(parts[j],2)
                if(j<length(parts)) printf ""
            }
            if(i<NF) printf "."
        }
    }'
}

# Validate UPM package ID: lowercase, reverse-DNS, no spaces
validate_package_id() {
    if [[ ! "$1" =~ ^[a-z][a-z0-9]*(\.[a-z][a-z0-9_-]*){2,}$ ]]; then
        return 1
    fi
    return 0
}

# Detect installed Unity versions, return highest
escape_sed() {
    printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'
}

detect_unity_min() {
    local hub="$HOME/Unity/Hub/Editor"
    [ -d "$hub" ] || { echo "2022.3"; return; }
    for d in "$hub"/*/; do
        local v
        v=$(basename "$d")
        if [[ "$v" =~ ^([0-9]+\.[0-9]+) ]]; then
            echo "${BASH_REMATCH[1]}"
            return
        fi
    done
    echo "2022.3"
}

# Detect GitHub owner from gh CLI
detect_github_owner() {
    if command -v gh >/dev/null 2>&1; then
        gh api user -q .login 2>/dev/null && return
    fi
    echo ""
}

# Detect git author name
detect_author() {
    local name=$(git config --global user.name 2>/dev/null)
    if [ -n "$name" ]; then
        echo "$name"
        return
    fi
    local owner=$(detect_github_owner)
    if [ -n "$owner" ]; then
        echo "$owner"
        return
    fi
    echo ""
}

# ── Banner ──────────────────────────────────────────────────────

echo ""
echo "  ${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo "  ${BOLD}║   ${CYAN}Unity UPM Package Creator${RESET}${BOLD}                          ║${RESET}"
echo "  ${BOLD}║   ${DIM}One command. Your package. Done.${RESET}${BOLD}                   ║${RESET}"
echo "  ${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""

# ── Smart defaults ──────────────────────────────────────────────

DEFAULT_AUTHOR=$(detect_author)
DEFAULT_UNITY=$(detect_unity_min)
DEFAULT_GH_OWNER=$(detect_github_owner)

# ── Folder name → derive package ID suggestion ──────────────────

if [ -z "$FOLDER_NAME" ]; then
    FOLDER_NAME=$(basename "$(pwd)")
    # Skip obvious non-project dirs
    case "$FOLDER_NAME" in
        tmp|home|root|usr|var|etc|Users|Documents|Desktop|Downloads|"$HOME") FOLDER_NAME="" ;;
    esac
    if [ -n "$FOLDER_NAME" ]; then
        read -rp "  ${BOLD}Folder name${RESET} [$FOLDER_NAME]: " INPUT
        FOLDER_NAME="${INPUT:-$FOLDER_NAME}"
    else
        read -rp "  ${BOLD}Folder name${RESET} (e.g. grid-pathfinding): " FOLDER_NAME
    fi
fi

if [ -z "$FOLDER_NAME" ]; then
    echo "  Need a folder name." && exit 1
fi

if [ -d "$FOLDER_NAME" ]; then
    echo "  '$FOLDER_NAME' already exists." && exit 1
fi

# Derive a suggested package ID from folder name
SUGGESTED_ID=""
OWNER_HINT=""
if [ -n "$DEFAULT_GH_OWNER" ]; then
    # lowercase the owner, strip spaces
    OWNER_HINT=$(echo "$DEFAULT_GH_OWNER" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
fi
if [[ "$FOLDER_NAME" =~ ^[a-z]+(\.[a-z0-9_-]+){2,}$ ]]; then
    # Already looks like a package ID (e.g. com.bovinelabs.grid)
    SUGGESTED_ID="$FOLDER_NAME"
elif [ -n "$OWNER_HINT" ]; then
    # folder name → com.owner.folder-name
    SUGGESTED_ID="com.${OWNER_HINT}.$(echo "$FOLDER_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
fi

# ── Gather inputs ───────────────────────────────────────────────

echo ""
echo "  ${DIM}── Identity ─────────────────────────────────────────${RESET}"
echo ""

if [ -n "$SUGGESTED_ID" ]; then
    read -rp "  ${BOLD}Package ID${RESET} [$SUGGESTED_ID]: " PACKAGE_ID
    PACKAGE_ID="${PACKAGE_ID:-$SUGGESTED_ID}"
else
    read -rp "  ${BOLD}Package ID${RESET} (e.g. com.bovinelabs.grid.pathfinding): " PACKAGE_ID
fi

# Validate
if ! validate_package_id "$PACKAGE_ID"; then
    echo "  ${YELLOW}⚠${RESET} Invalid package ID. Must be lowercase reverse-DNS (e.g. com.owner.name)." && exit 1
fi

DERIVED_NAMESPACE=$(package_to_namespace "$PACKAGE_ID")
DERIVED_DISPLAY=$(pascal "$(echo "$PACKAGE_ID" | awk -F'.' '{print $NF}')")

read -rp "  ${BOLD}Display name${RESET} [$DERIVED_DISPLAY]: " DISPLAY_NAME
DISPLAY_NAME="${DISPLAY_NAME:-$DERIVED_DISPLAY}"

if [ -n "$DEFAULT_AUTHOR" ]; then
    read -rp "  ${BOLD}Author${RESET} [$DEFAULT_AUTHOR]: " AUTHOR
    AUTHOR="${AUTHOR:-$DEFAULT_AUTHOR}"
else
    read -rp "  ${BOLD}Author${RESET} (e.g. Vex Interactive): " AUTHOR
fi

read -rp "  ${BOLD}C# namespace${RESET} [$DERIVED_NAMESPACE]: " NAMESPACE
NAMESPACE="${NAMESPACE:-$DERIVED_NAMESPACE}"

# GitHub owner (for install URL) — separate from display author
if [ -n "$DEFAULT_GH_OWNER" ]; then
    GH_OWNER="$DEFAULT_GH_OWNER"
else
    read -rp "  ${BOLD}GitHub owner/org${RESET}: " GH_OWNER
fi

YEAR=$(date +%Y)

# Unity minimum — auto-detected
if [ -n "$DEFAULT_UNITY" ]; then
    read -rp "  ${BOLD}Unity minimum${RESET} [$DEFAULT_UNITY]: " UNITY_MIN
    UNITY_MIN="${UNITY_MIN:-$DEFAULT_UNITY}"
else
    UNITY_MIN="2022.3"
fi

# Escape all values for safe sed replacement
S_PACKAGE=$(escape_sed "$PACKAGE_ID")
S_NAMESPACE=$(escape_sed "$NAMESPACE")
S_DISPLAY=$(escape_sed "$DISPLAY_NAME")
S_AUTHOR=$(escape_sed "$AUTHOR")
S_YEAR=$(escape_sed "$YEAR")
S_UNITY=$(escape_sed "$UNITY_MIN")

echo ""
echo "  ${DIM}──────────────────────────────────────────────────────${RESET}"
echo "  ${BOLD}Package:${RESET}    $PACKAGE_ID"
echo "  ${BOLD}Display:${RESET}     $DISPLAY_NAME"
echo "  ${BOLD}Author:${RESET}      $AUTHOR"
echo "  ${BOLD}Namespace:${RESET}   $NAMESPACE"
echo "  ${BOLD}GitHub:${RESET}      $GH_OWNER"
echo "  ${BOLD}Unity:${RESET}       $UNITY_MIN+"
echo "  ${BOLD}Folder:${RESET}      $FOLDER_NAME"
echo "  ${DIM}──────────────────────────────────────────────────────${RESET}"
echo ""
read -rp "  ${BOLD}Create?${RESET} [Y/n] " CONFIRM
[[ "$CONFIRM" =~ ^[Nn] ]] && echo "  Aborted." && exit 0

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

# ── Personalize all files ───────────────────────────────────────

echo "  ${GREEN}►${RESET} Personalizing..."

find . -type f \( -name "*.cs" -o -name "*.csproj" -o -name "*.slnx" -o -name "*.asmdef" \
    -o -name "*.json" -o -name "*.yml" -o -name "*.md" -o -name "*.sh" -o -name "*.ps1" \
    -o -name "LICENSE" \) \
    -not -path "*/bin/*" -not -path "*/obj/*" -not -path "*/.git/*" \
    -exec sed -i \
    -e "s/__PACKAGE__/$S_PACKAGE/g" \
    -e "s/__NAMESPACE__/$S_NAMESPACE/g" \
    -e "s/__DISPLAY__/$S_DISPLAY/g" \
    -e "s/__DESCRIPTION__/$S_DISPLAY/g" \
    -e "s/__AUTHOR__/$S_AUTHOR/g" \
    -e "s/__YEAR__/$S_YEAR/g" \
    -e "s/__UNITY_MIN__/$S_UNITY/g" \
    {} +

# ── Clean placeholder source files ──────────────────────────────

find . -name "__PLACEHOLDER__*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f")
    base=$(basename "$f")
    newname=$(echo "$base" | sed "s/__PLACEHOLDER__/Template/g")
    mv "$f" "$dir/$newname"
done

# ── Erase every trace of the template ───────────────────────────

echo "  ${GREEN}►${RESET} Cleaning up..."
rm -f setup.sh install.sh AGENTS.md CHANGELOG.md
chmod +x scripts/*.sh

# Remove GameCI workflows — they need Unity license secrets the user hasn't set up yet
# Users can re-add them from the template repo when ready
rm -f .github/workflows/unity-package-test.yml
rm -f .github/workflows/unity-activation.yml
rm -f .github/workflows/release.yml
rm -f .github/workflows/ai-context.yml

# Remove sample code — user will write their own
rm -rf Samples~ Documentation~ Skills~

# Remove tools — only needed for template development
rm -rf tools

# Remove samples key from package.json (no samples to show)
python3 -c "
import json
with open('package.json') as f: d = json.load(f)
d.pop('samples', None)
with open('package.json', 'w') as f: json.dump(d, f, indent=2)
" 2>/dev/null || true

# Write a clean README — no template fingerprints
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

# ── Verify build ────────────────────────────────────────────────

echo "  ${GREEN}►${RESET} Restoring..."
if ! dotnet restore "$PACKAGE_ID.slnx" >/dev/null 2>&1; then
    echo "  ${YELLOW}⚠${RESET} Restore failed. Check .NET SDK version."
    exit 1
fi

echo "  ${GREEN}►${RESET} Building..."
if ! dotnet build "$PACKAGE_ID.slnx" -c Release --no-restore >/dev/null 2>&1; then
    echo "  ${YELLOW}⚠${RESET} Build failed."
    exit 1
fi

echo "  ${GREEN}►${RESET} Testing..."
if ! dotnet test "$PACKAGE_ID.slnx" -c Release --no-build 2>&1; then
    echo "  ${RED}✗${RESET} Tests failed. Aborting."
    exit 1
fi

# ── Verify no leftover placeholders ─────────────────────────────

LEFTOVER=$(grep -rl '__[A-Z_]*__' \
    --include='*.cs' --include='*.json' --include='*.asmdef' \
    . 2>/dev/null | grep -v '/obj/' | grep -v '/bin/' | grep -v '.github/' || true)
if [ -n "$LEFTOVER" ]; then
    echo "  ${RED}✗${RESET} Unreplaced placeholders in:"
    echo "$LEFTOVER" | sed 's/^/    /'
    exit 1
fi

# ── Git init ────────────────────────────────────────────────────

echo "  ${GREEN}►${RESET} Initializing..."
git init >/dev/null 2>&1
git add -A >/dev/null 2>&1

if ! git commit -m "init" >/dev/null 2>&1; then
    echo "  ${DIM}Git commit failed — configure user.name/user.email then commit manually.${RESET}"
fi
git branch -M main >/dev/null 2>&1

# ── GitHub push ─────────────────────────────────────────────────

echo ""
if command -v gh >/dev/null 2>&1; then
    read -rp "  ${BOLD}Push to GitHub?${RESET} [Y/n] " PUSH_GH
    if [[ ! "$PUSH_GH" =~ ^[Nn] ]]; then
        read -rp "  ${BOLD}Repo name${RESET} [$PACKAGE_ID]: " GH_REPO
        GH_REPO="${GH_REPO:-$PACKAGE_ID}"
        read -rp "  ${BOLD}Visibility${RESET} [public]: " GH_VIS
        GH_VIS="${GH_VIS:-public}"
        # Accept truthy as public
        case "$GH_VIS" in pub|public|p|y|yes|Y|YES) GH_VIS="public";; priv|private|n|no|N|NO) GH_VIS="private";; *) GH_VIS="public";; esac

        echo "  ${GREEN}►${RESET} Pushing..."
        if gh repo create "$GH_OWNER/$GH_REPO" --${GH_VIS} --source=. --push \
            --description "$DISPLAY_NAME" 2>&1 | head -1; then
            echo "  ${GREEN}✓${RESET} ${BOLD}github.com/$GH_OWNER/$GH_REPO${RESET}"
        else
            echo "  ${DIM}Push failed. Create manually: gh repo create then git push -u origin main${RESET}"
        fi
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
