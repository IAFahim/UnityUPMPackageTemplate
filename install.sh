#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_REPO="https://github.com/IAFahim/UnityUPMPackageTemplate.git"
FOLDER_NAME=""
FORCE_YES=false

for arg in "$@"; do
    case "$arg" in
        --yes) FORCE_YES=true ;;
        -*) echo "Unknown option: $arg"; exit 1 ;;
        *) FOLDER_NAME="$arg" ;;
    esac
done

BOLD=$'\033[1m' DIM=$'\033[2m' GREEN=$'\033[32m' CYAN=$'\033[36m' YELLOW=$'\033[33m' RESET=$'\033[0m'

pascal() {
    echo "$1" | sed 's/[-_ ]\+/_/g' | awk -F'_' '{for(i=1;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)), substr($i,2)}'
}

package_to_namespace() {
    echo "$1" | awk -F'.' '{
        for(i=2;i<=NF;i++) {
            split($i, parts, /[-_]/)
            for(j=1;j<=length(parts);j++) {
                printf "%s%s", toupper(substr(parts[j],1,1)), substr($i,2)
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
    [ -n "$name" ] && echo "$name" && return
    local owner=$(detect_github_owner)
    [ -n "$owner" ] && echo "$owner" && return
    echo ""
}

detect_dotnet_version() {
    dotnet --version 2>/dev/null | awk -F. '{print $1".0"}' || echo "net10.0"
}

echo ""
echo "  ${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo "  ${BOLD}║   ${CYAN}Unity UPM Package Creator${RESET}${BOLD}                          ║${RESET}"
echo "  ${BOLD}║   ${DIM}Build outside Unity. Ship as Unity package.${RESET}${BOLD}       ║${RESET}"
echo "  ${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""

DEFAULT_AUTHOR=$(detect_author)
DEFAULT_UNITY=$(detect_unity_min)
DEFAULT_GH_OWNER=$(detect_github_owner)
DEFAULT_DOTNET=$(detect_dotnet_version)

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

[ -z "$FOLDER_NAME" ] && echo "  Need a folder name." && exit 1
[ -d "$FOLDER_NAME" ] && echo "  '$FOLDER_NAME' already exists." && exit 1

SUGGESTED_ID=""
OWNER_HINT=$(echo "$DEFAULT_GH_OWNER" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
if [[ "$FOLDER_NAME" =~ ^[a-z]+(\.[a-z0-9_-]+){2,}$ ]]; then
    SUGGESTED_ID="$FOLDER_NAME"
elif [ -n "$OWNER_HINT" ]; then
    SUGGESTED_ID="com.${OWNER_HINT}.$(echo "$FOLDER_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
fi

if [ "$FORCE_YES" = true ]; then
    PACKAGE_ID="${SUGGESTED_ID:-com.example.package}"
    DISPLAY_NAME=$(pascal "$(echo "$PACKAGE_ID" | awk -F'.' '{print $NF}')")
    AUTHOR="${DEFAULT_AUTHOR:-Example Author}"
    NAMESPACE=$(package_to_namespace "$PACKAGE_ID")
    GH_OWNER="${DEFAULT_GH_OWNER:-example}"
    UNITY_MIN="$DEFAULT_UNITY"
else
    echo ""
    echo "  ${DIM}── Identity ─────────────────────────────────────────${RESET}"
    echo ""

    if [ -n "$SUGGESTED_ID" ]; then
        read -rp "  ${BOLD}Package ID${RESET} [$SUGGESTED_ID]: " PACKAGE_ID
        PACKAGE_ID="${PACKAGE_ID:-$SUGGESTED_ID}"
    else
        read -rp "  ${BOLD}Package ID${RESET} (e.g. com.bovinelabs.grid): " PACKAGE_ID
    fi

    if ! validate_package_id "$PACKAGE_ID"; then
        echo "  ${YELLOW}⚠${RESET} Invalid package ID." && exit 1
    fi

    DERIVED_NAMESPACE=$(package_to_namespace "$PACKAGE_ID")
    DERIVED_DISPLAY=$(pascal "$(echo "$PACKAGE_ID" | awk -F'.' '{print $NF}')")

    read -rp "  ${BOLD}Display name${RESET} [$DERIVED_DISPLAY]: " DISPLAY_NAME
    DISPLAY_NAME="${DISPLAY_NAME:-$DERIVED_DISPLAY}"

    read -rp "  ${BOLD}Author${RESET} [${DEFAULT_AUTHOR:-IAFahim}]: " AUTHOR
    AUTHOR="${AUTHOR:-${DEFAULT_AUTHOR:-IAFahim}}"

    read -rp "  ${BOLD}C# namespace${RESET} [$DERIVED_NAMESPACE]: " NAMESPACE
    NAMESPACE="${NAMESPACE:-$DERIVED_NAMESPACE}"

    read -rp "  ${BOLD}GitHub owner/org${RESET} [${DEFAULT_GH_OWNER:-example}]: " GH_OWNER
    GH_OWNER="${GH_OWNER:-${DEFAULT_GH_OWNER:-example}}"

    read -rp "  ${BOLD}Unity minimum${RESET} [$DEFAULT_UNITY]: " UNITY_MIN
    UNITY_MIN="${UNITY_MIN:-$DEFAULT_UNITY}"

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
S_DOTNET=$(escape_sed "$DEFAULT_DOTNET")

echo ""
echo "  ${GREEN}►${RESET} Cloning..."
git clone --depth 1 "$TEMPLATE_REPO" "$FOLDER_NAME" 2>/dev/null
cd "$FOLDER_NAME"
rm -rf .git

echo "  ${GREEN}►${RESET} Building structure..."

[ -d "__PACKAGE__" ] && mv "__PACKAGE__" "$PACKAGE_ID"
[ -d "Dev~/src/__PACKAGE__" ] && mv "Dev~/src/__PACKAGE__" "Dev~/src/$PACKAGE_ID"
[ -d "Dev~/tests/__PACKAGE__.Tests" ] && mv "Dev~/tests/__PACKAGE__.Tests" "Dev~/tests/$PACKAGE_ID.Tests"
[ -f "__PACKAGE__.slnx" ] && mv "__PACKAGE__.slnx" "$PACKAGE_ID.slnx"

find . -type f -name "__PACKAGE__*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f"); base=$(basename "$f")
    newname=$(echo "$base" | sed "s/__PACKAGE__/$PACKAGE_ID/g")
    [ "$base" != "$newname" ] && mv "$f" "$dir/$newname"
done

echo "  ${GREEN}►${RESET} Personalizing..."

find . -type f \( -name "*.cs" -o -name "*.csproj" -o -name "*.slnx" -o -name "*.asmdef" \
    -o -name "*.json" -o -name "*.yml" -o -name "*.md" -o -name "*.sh" \
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
    -e "s/__TEST_NET__/$S_DOTNET/g" \
    {} +

find . -type f -name "__PLACEHOLDER__*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f"); base=$(basename "$f")
    newname=$(echo "$base" | sed "s/__PLACEHOLDER__/Template/g")
    mv "$f" "$dir/$newname"
done

# ── Flatten for UPM (BovineLabs-style) ──────────────────────────

echo "  ${GREEN}►${RESET} Flattening for UPM..."

for subdir in "$PACKAGE_ID"/*/; do
    [ -d "$subdir" ] || continue
    base=$(basename "$subdir")

    if [ ! -e "$base" ]; then
        mv "$subdir" "./$base"
        [ -f "${subdir%/}.meta" ] && mv "${subdir%/}.meta" "./$base.meta"
    else
        for item in "$subdir"*; do
            [ -e "$item" ] || continue
            item_base=$(basename "$item")
            [ ! -e "$item_base" ] && mv "$item" "./$item_base"
        done
        [ -f "${subdir%/}.meta" ] && rm -f "${subdir%/}.meta"
    fi
done

for f in "$PACKAGE_ID"/*; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    [ -d "$f" ] && continue

    if [ ! -e "$base" ]; then
        mv "$f" "./$base"
        [ -f "$f.meta" ] && mv "$f.meta" "./$base.meta"
    fi
done

rm -rf "$PACKAGE_ID"

# ── Move dev-only into Dev~/infra/ ──────────────────────────────

mkdir -p Dev~/infra

for f in "$PACKAGE_ID.slnx"; do
    [ -e "$f" ] && mv "$f" Dev~/infra/
done

# Directory.Build.props → Dev~/src/ and Dev~/tests/
[ -e "Directory.Build.props" ] && mv "Directory.Build.props" Dev~/src/
[ -e "Dev~/src/Directory.Build.props" ] && cp "Dev~/src/Directory.Build.props" Dev~/tests/

# ── Clean up template artifacts ─────────────────────────────────

echo "  ${GREEN}►${RESET} Cleaning up..."
rm -f setup.sh install.sh AGENTS.md CHANGELOG.md 2>/dev/null || true
rm -f Dev~/infra/scripts/test-template.sh Dev~/infra/scripts/test-cli.sh 2>/dev/null || true

find . -name "*~.meta" -delete

# ── Generate clean README ────────────────────────────────────────

cat > README.md <<README
# $DISPLAY_NAME

[![CI](https://github.com/$GH_OWNER/$PACKAGE_ID/actions/workflows/ci.yml/badge.svg)](https://github.com/$GH_OWNER/$PACKAGE_ID/actions)
[![License](https://img.shields.io/github/license/$GH_OWNER/$PACKAGE_ID)](LICENSE)

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

## How it works

\`\`\`
Runtime/*.cs          ← your code (uses Unity.Mathematics types)
  │
  ├─ dotnet build     ← UnityMathematics.NoDeps NuGet
  │   dotnet test     ← same NuGet, no Unity needed
  │
  └─ Unity            ← com.unity.mathematics UPM via package.json
\`\`\`

No DLLs. No Unity project needed to develop. Same source compiles in both.

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
echo "  1. Push:  ${DIM}gh repo create $GH_OWNER/$PACKAGE_ID --public --source=. --push${RESET}"
echo "  2. Build: ${DIM}dotnet test -c Release${RESET}"
echo ""
