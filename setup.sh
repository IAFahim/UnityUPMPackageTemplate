#!/usr/bin/env bash
set -euo pipefail

BOLD=$'\033[1m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
RESET=$'\033[0m'

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

escape_sed() {
    printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'
}

detect_author()   { git config --global user.name 2>/dev/null || gh api user -q .login 2>/dev/null || echo "Unknown Author"; }
detect_email()    { git config --global user.email 2>/dev/null || echo ""; }
detect_gh_owner() { gh api user -q .login 2>/dev/null || echo ""; }

# ── Gather inputs ───────────────────────────────────────────────

FORCE_YES=false
if [[ "$*" == *"--yes"* ]]; then
    FORCE_YES=true
fi

DEFAULT_AUTHOR=$(detect_author)
DEFAULT_EMAIL=$(detect_email)
DEFAULT_GH=$(detect_gh_owner)
DERIVED_ID="" DERIVED_NS="" DERIVED_DISPLAY=""

# Derive from folder name if it looks like a package ID
FOLDER=$(basename "$(pwd)")
if [[ "$FOLDER" =~ ^[a-z]+(\.[a-z0-9_-]+){2,}$ ]]; then
    DERIVED_ID="$FOLDER"
    DERIVED_NS=$(package_to_namespace "$FOLDER")
    DERIVED_DISPLAY=$(pascal "$(echo "$FOLDER" | awk -F'.' '{print $NF}')")
elif [ -n "$DEFAULT_GH" ]; then
    CLEAN_OWNER=$(echo "$DEFAULT_GH" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    CLEAN_FOLDER=$(echo "$FOLDER" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    DERIVED_ID="com.$CLEAN_OWNER.$CLEAN_FOLDER"
    DERIVED_NS=$(package_to_namespace "$DERIVED_ID")
    DERIVED_DISPLAY=$(pascal "$FOLDER")
fi

if [ "$FORCE_YES" = true ]; then
    PACKAGE_ID="${DERIVED_ID:-com.example.package}"
    DISPLAY_NAME="${DERIVED_DISPLAY:-Example Package}"
    AUTHOR="${DEFAULT_AUTHOR:-Example Author}"
    NAMESPACE="${DERIVED_NS:-Example.Package}"
    LICENSE="MIT"
    SAMPLES="3"
elif [ $# -ge 4 ]; then
    PACKAGE_ID="$1"; DISPLAY_NAME="$2"; AUTHOR="$3"; NAMESPACE="$4"
    LICENSE="MIT"
    SAMPLES="3"
elif [ $# -ge 3 ]; then
    PACKAGE_ID="$1"; DISPLAY_NAME="$2"; AUTHOR="$3"
    NAMESPACE=$(package_to_namespace "$PACKAGE_ID")
    LICENSE="MIT"
    SAMPLES="3"
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

    # License
    read -rp "  License [MIT]: " LICENSE
    LICENSE="${LICENSE:-MIT}"

    echo ""
    echo "  Create samples?"
    echo "  [1] None"
    echo "  [2] QuickStart scene"
    echo "  [3] QuickStart + UI Toolkit demo"
    read -rp "  Selection [3]: " SAMPLES
    SAMPLES="${SAMPLES:-3}"

    echo ""
    echo "  Package:   $PACKAGE_ID"
    echo "  Display:   $DISPLAY_NAME"
    echo "  Author:    $AUTHOR"
    echo "  Namespace: $NAMESPACE"
    echo "  License:   $LICENSE"
    echo ""
    read -rp "  Create? [Y/n] " CONFIRM
    [[ "$CONFIRM" =~ ^[Nn] ]] && exit 1
fi

if ! validate_package_id "$PACKAGE_ID"; then
    echo "  Invalid package ID. Must be lowercase reverse-DNS." && exit 1
fi

YEAR=$(date +%Y)
GH_OWNER="${DEFAULT_GH:-$AUTHOR}"
UNITY_MIN="2022.3"

# Detect Unity
if [ -d "$HOME/Unity/Hub/Editor" ]; then
    for d in "$HOME/Unity/Hub/Editor"/*/; do
        v=$(basename "$d")
        [[ "$v" =~ ^([0-9]+\.[0-9]+) ]] && UNITY_MIN="${BASH_REMATCH[1]}" && break
    done
fi

# Escape for sed
S_PACKAGE=$(escape_sed "$PACKAGE_ID")
S_NAMESPACE=$(escape_sed "$NAMESPACE")
S_DISPLAY=$(escape_sed "$DISPLAY_NAME")
S_AUTHOR=$(escape_sed "$AUTHOR")
S_YEAR=$(escape_sed "$YEAR")
S_UNITY=$(escape_sed "$UNITY_MIN")
S_LICENSE=$(escape_sed "$LICENSE")
echo ""

# ── Rename folders ──────────────────────────────────────────────

echo "  Setting up..."
[ -d "__PACKAGE__" ]                  && mv "__PACKAGE__"                  "$PACKAGE_ID"
[ -d "Dev~/src/__PACKAGE__" ]         && mv "Dev~/src/__PACKAGE__"         "Dev~/src/$PACKAGE_ID"
[ -d "Dev~/tests/__PACKAGE__.Tests" ] && mv "Dev~/tests/__PACKAGE__.Tests" "Dev~/tests/$PACKAGE_ID.Tests"
[ -d "Dev~/benchmarks/__PACKAGE__.Benchmarks" ] && mv "Dev~/benchmarks/__PACKAGE__.Benchmarks" "Dev~/benchmarks/$PACKAGE_ID.Benchmarks"
[ -f "__PACKAGE__.slnx" ]             && mv "__PACKAGE__.slnx"             "$PACKAGE_ID.slnx"

# ── Rename files ────────────────────────────────────────────────

find . -type f -name "__PACKAGE__*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f"); base=$(basename "$f")
    newname=$(echo "$base" | sed "s/__PACKAGE__/$PACKAGE_ID/g")
    if [ "$base" != "$newname" ]; then
        if [ -e "$dir/$newname" ]; then
            rm -f "$f"
        else
            mv "$f" "$dir/$newname"
        fi
    fi
done

# ── Personalize ─────────────────────────────────────────────────

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
    -e "s/MIT/$S_LICENSE/g" \
    {} +

# ── Clean placeholders ──────────────────────────────────────────

find . -type f -name "__PLACEHOLDER__*" -not -path "*/bin/*" -not -path "*/obj/*" | while read -r f; do
    dir=$(dirname "$f"); base=$(basename "$f")
    newname=$(echo "$base" | sed 's/__PLACEHOLDER__/Template/')
    if [ -e "$dir/$newname" ]; then
        rm -f "$f"
    else
        mv "$f" "$dir/$newname"
    fi
done

# ── Samples ─────────────────────────────────────────────────────
if [ "$SAMPLES" = "1" ]; then
    rm -rf Samples~
    python3 -c "import json; d=json.load(open('package.json')); d.pop('samples',None); json.dump(d,open('package.json','w'),indent=2)" 2>/dev/null || true
elif [ "$SAMPLES" = "2" ]; then
    rm -rf Samples~/UIToolkitDemo
    python3 -c "import json; d=json.load(open('package.json')); d['samples']=[s for s in d['samples'] if 'QuickStart' in s['path']]; json.dump(d,open('package.json','w'),indent=2)" 2>/dev/null || true
fi

# ── Erase all traces ────────────────────────────────────────────

chmod +x scripts/*.sh

# Remove template-only root files from generated packages.
rm -f AGENTS.md install.sh CHANGELOG.md TODO-FEATURES.md

# Remove template-only test scripts from generated packages.
rm -f scripts/test-template.sh scripts/test-cli.sh

# Keep .github/ because generated packages should still have CI.
rm -- "$0"

# Clean README
BADGE_URL="https://github.com/$GH_OWNER/$PACKAGE_ID/actions/workflows/ci.yml/badge.svg"
OPENUPM_BADGE_URL="https://img.shields.io/npm/v/$PACKAGE_ID?label=openupm&registry_uri=https://package.openupm.com"
DOCS_BADGE="https://img.shields.io/badge/docs-pages-blue"
DOCS_URL="https://$GH_OWNER.github.io/$PACKAGE_ID"
BADGE_LICENSE="https://img.shields.io/github/license/$GH_OWNER/$PACKAGE_ID"
BADGE_UNITY="https://img.shields.io/badge/Unity-$UNITY_MIN%2B-black?logo=unity"

cat > README.md <<README
# $DISPLAY_NAME

[![CI]($BADGE_URL)](https://github.com/$GH_OWNER/$PACKAGE_ID/actions)
[![License]($BADGE_LICENSE)](LICENSE)
[![Unity]($BADGE_UNITY)](https://unity.com)
[![OpenUPM]($OPENUPM_BADGE_URL)](https://openupm.com/packages/$PACKAGE_ID/)
[![Docs]($DOCS_BADGE)]($DOCS_URL)

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

## Where code lives

| What | Where |
|------|-------|
| Runtime types | \`$PACKAGE_ID/Runtime/\` |
| Tests | \`$PACKAGE_ID/Tests/\` |
| Editor code | \`$PACKAGE_ID/Editor/\` |
| Samples | \`Samples~/\` |
| Source generators | \`SourceGenerator~/\` |
| Runtime resources | \`Plugins~/\` |
| Docs | \`Documentation~/\` |

Write your code in Runtime/. Tests in Tests/. Both Unity and dotnet compile the same files.

## Dev

\`\`\`bash
dotnet restore
dotnet test -c Release
bash scripts/smoke.sh
\`\`\`

Git hooks are pre-installed. Re-install after cloning: \`bash scripts/install-hooks.sh\`

## Scripts

| Command | What it does |
|---------|-------------|
| \`bash scripts/smoke.sh\` | Build + test + validate |
| \`bash scripts/doctor.sh\` | Full diagnostic (28+ checks) |
| \`bash scripts/version.sh 0.2.0\` | Bump version + changelog |
| \`bash scripts/pre-release.sh 0.2.0\` | Pre-release checklist |

## Release

\`\`\`bash
bash scripts/version.sh 0.2.0           # bump version + changelog
bash scripts/pre-release.sh 0.2.0       # verify everything is ready
git tag v0.2.0 && git push --tags       # trigger release CI
\`\`\`

MIT © $YEAR $AUTHOR
README


# mkdocs configuration for GitHub Pages
cat > mkdocs.yml <<MKDOCS
site_name: $DISPLAY_NAME
site_description: $DISPLAY_NAME Unity Package
docs_dir: Documentation~
repo_url: https://github.com/$GH_OWNER/$PACKAGE_ID
repo_name: $GH_OWNER/$PACKAGE_ID

theme:
  name: material
  palette:
    scheme: slate
    primary: deep purple
  features:
    - navigation.tabs
    - navigation.instant

nav:
  - Home: index.md
  - Installation: installation.md
  - Quick Start: quick-start.md
  - API Reference: api.md
  - Release Notes: release-notes.md
MKDOCS
echo "  ${GREEN}✓${RESET} mkdocs.yml created"

# Install git hooks if git is available
if git rev-parse --git-dir >/dev/null 2>&1 && [ -d "scripts/hooks" ]; then
    bash scripts/install-hooks.sh >/dev/null 2>&1 || true
    echo "  ${GREEN}✓${RESET} Git hooks installed"
fi

# Create initial API baseline
if dotnet build "$PACKAGE_ID.slnx" -c Release --nologo -v quiet >/dev/null 2>&1; then
    bash scripts/api-surface.sh artifacts/api/baseline.txt 2>/dev/null || true
    echo "  ${GREEN}✓${RESET} API baseline created"
fi

TEMPLATE_SHA=$(git -C "$(dirname "$0")" rev-parse HEAD 2>/dev/null || echo "unknown")
cat > .template-version <<VER
# Auto-generated by setup.sh — do not edit
template_sha: $TEMPLATE_SHA
generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
VER

echo ""
echo "  Done."
echo ""
echo "    Edit:  $PACKAGE_ID/Runtime/"
echo "    Test:  dotnet test -c Release"
echo ""
