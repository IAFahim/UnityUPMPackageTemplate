#!/usr/bin/env bash
# ── Export .unitypackage using Unity batch mode ─────────────────
set -euo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' RESET=$'\033[0m'

echo ""
echo "  ${BOLD}Exporting .unitypackage...${RESET}"

# ── Detect Unity ────────────────────────────────────────────────

UNITY_PATH=""
if command -v Unity >/dev/null 2>&1; then
    UNITY_PATH="Unity"
elif [ -d "/Applications/Unity/Hub/Editor" ]; then
    UNITY_PATH=$(find "/Applications/Unity/Hub/Editor" -name "Unity" -type f | sort -r | head -1)
elif [ -d "$HOME/Unity/Hub/Editor" ]; then
    UNITY_PATH=$(find "$HOME/Unity/Hub/Editor" -name "Unity" -type f | sort -r | head -1)
fi

if [ -z "$UNITY_PATH" ]; then
    echo "  ${RED}✗${RESET} Unity not found. Skipping .unitypackage export."
    exit 0 # Don't fail the script, just skip if no Unity
fi

# ── Prepare temp project ────────────────────────────────────────

TMP_PROJECT="artifacts/export-project"
rm -rf "$TMP_PROJECT"
mkdir -p "$TMP_PROJECT/Assets/Editor"
mkdir -p "artifacts/release"

# Get package info
PACKAGE_ID=$(python3 -c "import json; print(json.load(open('package.json'))['name'])" 2>/dev/null || echo "com.unknown.package")
DISPLAY_NAME=$(python3 -c "import json; print(json.load(open('package.json'))['displayName'])" 2>/dev/null || echo "Package")

echo "  Package: $PACKAGE_ID"
echo "  Project: $TMP_PROJECT"

# Copy package contents into temp project
mkdir -p "$TMP_PROJECT/Assets/$DISPLAY_NAME"
rsync -a --exclude='.git' --exclude='.github' --exclude='bin' --exclude='obj' --exclude='artifacts' ./ "$TMP_PROJECT/Assets/$DISPLAY_NAME/"

# Copy exporter tool
cp tools/UnityPackageExporter/UnityPackageExporter.cs "$TMP_PROJECT/Assets/Editor/"

# ── Run Unity ───────────────────────────────────────────────────

echo "  Running Unity batchmode..."

export PACKAGE_ID="$PACKAGE_ID"
export PACKAGE_DISPLAY_NAME="$DISPLAY_NAME"
export RELEASE_OUT="artifacts/release"

"$UNITY_PATH" -batchmode -nographics -quit \
    -projectPath "$TMP_PROJECT" \
    -executeMethod UnityPackageExporter.Export \
    -logFile "artifacts/unity-export.log"

if [ -f "artifacts/release/$PACKAGE_ID.unitypackage" ]; then
    echo "  ${GREEN}✓${RESET} Exported: artifacts/release/$PACKAGE_ID.unitypackage"
else
    echo "  ${RED}✗${RESET} Export failed. See artifacts/unity-export.log"
    exit 1
fi

echo ""
