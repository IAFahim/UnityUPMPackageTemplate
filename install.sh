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
FOLDER_NAME=""
FORCE_YES=false
MINIMAL=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --yes) FORCE_YES=true ;;
        --minimal) MINIMAL=true ;;
        -*) echo "Unknown option: $arg"; exit 1 ;;
        *) FOLDER_NAME="$arg" ;;
    esac
done

BOLD=$'\033[1m' DIM=$'\033[2m' GREEN=$'\033[32m' CYAN=$'\033[36m' YELLOW=$'\033[33m' RED=$'\033[31m' RESET=$'\033[0m'

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

detect_github_owner() {
    if command -v gh >/dev/null 2>&1; then
        gh api user -q .login 2>/dev/null && return
    fi
    echo ""
}

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

# ── Folder name ─────────────────────────────────────────────────

if [ -z "$FOLDER_NAME" ]; then
    if [ "$FORCE_YES" = true ]; then
        FOLDER_NAME="my-unity-package"
    else
        FOLDER_NAME=$(basename "$(pwd)")
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
fi

if [ -z "$FOLDER_NAME" ]; then echo "  Need a folder name." && exit 1; fi
if [ -d "$FOLDER_NAME" ]; then echo "  '$FOLDER_NAME' already exists." && exit 1; fi

# Suggested ID
SUGGESTED_ID=""
OWNER_HINT=$(echo "$DEFAULT_GH_OWNER" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
if [[ "$FOLDER_NAME" =~ ^[a-z]+(\.[a-z0-9_-]+){2,}$ ]]; then
    SUGGESTED_ID="$FOLDER_NAME"
elif [ -n "$OWNER_HINT" ]; then
    SUGGESTED_ID="com.${OWNER_HINT}.$(echo "$FOLDER_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
fi

# ── Gather inputs ───────────────────────────────────────────────

if [ "$FORCE_YES" = true ]; then
    PACKAGE_ID="${SUGGESTED_ID:-com.example.package}"
    DISPLAY_NAME=$(pascal "$(echo "$PACKAGE_ID" | awk -F'.' '{print $NF}')")
    AUTHOR="${DEFAULT_AUTHOR:-Example Author}"
    NAMESPACE=$(package_to_namespace "$PACKAGE_ID")
    GH_OWNER="${DEFAULT_GH_OWNER:-example}"
    UNITY_MIN="$DEFAULT_UNITY"
    SAMPLES="3"
else
    echo ""
    echo "  ${DIM}── Identity ─────────────────────────────────────────${RESET}"
    echo ""

    if [ -n "$SUGGESTED_ID" ]; then
        read -rp "  ${BOLD}Package ID${RESET} [$SUGGESTED_ID]: " PACKAGE_ID
        PACKAGE_ID="${PACKAGE_ID:-$SUGGESTED_ID}"
    else
        read -rp "  ${BOLD}Package ID${RESET} (e.g. com.bovinelabs.grid.pathfinding): " PACKAGE_ID
    fi

    if ! validate_package_id "$PACKAGE_ID"; then
        echo "  ${YELLOW}⚠${RESET} Invalid package ID." && exit 1
    fi

    DERIVED_NAMESPACE=$(package_to_namespace "$PACKAGE_ID")
    DERIVED_DISPLAY=$(pascal "$(echo "$PACKAGE_ID" | awk -F'.' '{print $NF}')")

    read -rp "  ${BOLD}Display name${RESET} [$DERIVED_DISPLAY]: " DISPLAY_NAME
    DISPLAY_NAME="${DISPLAY_NAME:-$DERIVED_DISPLAY}"

    read -rp "  ${BOLD}Author${RESET} [${DEFAULT_AUTHOR:-Vex Interactive}]: " AUTHOR
    AUTHOR="${AUTHOR:-${DEFAULT_AUTHOR:-Vex Interactive}}"

    read -rp "  ${BOLD}C# namespace${RESET} [$DERIVED_NAMESPACE]: " NAMESPACE
    NAMESPACE="${NAMESPACE:-$DERIVED_NAMESPACE}"

    read -rp "  ${BOLD}GitHub owner/org${RESET} [${DEFAULT_GH_OWNER:-example}]: " GH_OWNER
    GH_OWNER="${GH_OWNER:-${DEFAULT_GH_OWNER:-example}}"

    read -rp "  ${BOLD}Unity minimum${RESET} [$DEFAULT_UNITY]: " UNITY_MIN
    UNITY_MIN="${UNITY_MIN:-$DEFAULT_UNITY}"

    echo ""
    echo "  ${BOLD}Create samples?${RESET}"
    echo "  [1] None"
    echo "  [2] QuickStart scene"
    echo "  [3] QuickStart + UI Toolkit demo"
    read -rp "  Selection [3]: " SAMPLES
    SAMPLES="${SAMPLES:-3}"

    echo ""
    echo "  ${DIM}──────────────────────────────────────────────────────${RESET}"
    echo "  ${BOLD}Package:${RESET}    $PACKAGE_ID"
    echo "  ${BOLD}Display:${RESET}     $DISPLAY_NAME"
    echo "  ${BOLD}Author:${RESET}      $AUTHOR"
    echo "  ${BOLD}Namespace:${RESET}   $NAMESPACE"
    echo "  ${BOLD}GitHub:${RESET}      $GH_OWNER"
    echo "  ${BOLD}Unity:${RESET}       $UNITY_MIN+"
    echo "  ${DIM}──────────────────────────────────────────────────────${RESET}"
    echo ""
    read -rp "  ${BOLD}Create?${RESET} [Y/n] " CONFIRM
    [[ "$CONFIRM" =~ ^[Nn] ]] && echo "  Aborted." && exit 0
fi

YEAR=$(date +%Y)
S_PACKAGE=$(escape_sed "$PACKAGE_ID")
S_NAMESPACE=$(escape_sed "$NAMESPACE")
S_DISPLAY=$(escape_sed "$DISPLAY_NAME")
S_AUTHOR=$(escape_sed "$AUTHOR")
S_YEAR=$(escape_sed "$YEAR")
S_UNITY=$(escape_sed "$UNITY_MIN")

# ── Clone & Build ───────────────────────────────────────────────

echo ""
echo "  ${GREEN}►${RESET} Cloning..."
git clone --depth 1 "$TEMPLATE_REPO" "$FOLDER_NAME" 2>/dev/null
cd "$FOLDER_NAME"
rm -rf .git

echo "  ${GREEN}►${RESET} Building structure..."

[ -d "__PACKAGE__.Runtime" ] && mv "__PACKAGE__.Runtime" "$PACKAGE_ID.Runtime"
[ -d "__PACKAGE__.Tests" ] && mv "__PACKAGE__.Tests" "$PACKAGE_ID.Tests"
[ -d "__PACKAGE__.Editor" ] && mv "__PACKAGE__.Editor" "$PACKAGE_ID.Editor"
[ -d "Dev~/src/__PACKAGE__" ] && mv "Dev~/src/__PACKAGE__" "Dev~/src/$PACKAGE_ID"
[ -d "Dev~/tests/__PACKAGE__.Tests" ] && mv "Dev~/tests/__PACKAGE__.Tests" "Dev~/tests/$PACKAGE_ID.Tests"
[ -d "Dev~/benchmarks/__PACKAGE__.Benchmarks" ] && mv "Dev~/benchmarks/__PACKAGE__.Benchmarks" "Dev~/benchmarks/$PACKAGE_ID.Benchmarks"
[ -f "__PACKAGE__.slnx" ] && mv "__PACKAGE__.slnx" "$PACKAGE_ID.slnx"

find . -type f -name "__PACKAGE__*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f"); base=$(basename "$f")
    newname=$(echo "$base" | sed "s/__PACKAGE__/$PACKAGE_ID/g")
    [ "$base" != "$newname" ] && mv "$f" "$dir/$newname"
done

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

find . -type f -name "__PLACEHOLDER__*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f"); base=$(basename "$f")
    newname=$(echo "$base" | sed "s/__PLACEHOLDER__/Template/g")
    mv "$f" "$dir/$newname"
done

# ── Samples ─────────────────────────────────────────────────────

if [ "$SAMPLES" = "1" ]; then
    rm -rf Samples~
    python3 -c "import json; d=json.load(open('package.json')); d.pop('samples',None); json.dump(d,open('package.json','w'),indent=2)" 2>/dev/null || true
elif [ "$SAMPLES" = "2" ]; then
    rm -rf Samples~/UIToolkitDemo
    python3 -c "import json; d=json.load(open('package.json')); d['samples']=[s for s in d['samples'] if 'QuickStart' in s['path']]; json.dump(d,open('package.json','w'),indent=2)" 2>/dev/null || true
fi

# ── Cleanup ─────────────────────────────────────────────────────

echo "  ${GREEN}►${RESET} Cleaning up..."
rm -f setup.sh install.sh AGENTS.md
chmod +x scripts/*.sh

if [ "$MINIMAL" = true ]; then
    rm -f .github/workflows/unity-package-test.yml .github/workflows/unity-activation.yml .github/workflows/release.yml .github/workflows/ai-context.yml
    rm -rf Samples~ Documentation~ Skills~ tools
fi

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

## Dev

\`\`\`bash
dotnet restore
dotnet test -c Release
\`\`\`

MIT © $YEAR $AUTHOR
README

# ── Finalize ────────────────────────────────────────────────────

echo "  ${GREEN}►${RESET} Initializing git..."
git init >/dev/null 2>&1
git add -A >/dev/null 2>&1
git commit -m "init" >/dev/null 2>&1 || true
git branch -M main >/dev/null 2>&1

echo ""
echo "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "  ${BOLD}  $DISPLAY_NAME is ready.${RESET}"
echo "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "  ${BOLD}Next:${RESET}"
echo "  1. Push to GitHub: ${DIM}gh repo create $GH_OWNER/$PACKAGE_ID --public --source=. --push${RESET}"
echo "  2. Setup secrets:  ${DIM}./scripts/setup-secrets.sh${RESET}"
echo "  3. Build & Test:   ${DIM}dotnet test -c Release${RESET}"
echo ""
