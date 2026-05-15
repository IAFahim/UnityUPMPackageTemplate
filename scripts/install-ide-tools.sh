#!/usr/bin/env bash
# Usage: bash scripts/install-ide-tools.sh [--rider] [--vscode]
set -euo pipefail

RIDER=false; VSCODE=false
[ $# -eq 0 ] && RIDER=true && VSCODE=true
for arg in "$@"; do
    case "$arg" in --rider) RIDER=true ;; --vscode) VSCODE=true ;; esac
done

ROOT="$(git rev-parse --show-toplevel)"
TOOLS="$ROOT/Tools~"

if $RIDER; then
    RIDER_TEMPLATES="$HOME/.config/JetBrains/Rider*/templates"
    if ls $RIDER_TEMPLATES >/dev/null 2>&1; then
        cp "$TOOLS/rider-live-templates.xml" $(ls -d $RIDER_TEMPLATES | head -1)/
        echo "  ✓ Rider live templates installed"
    else
        echo "  ⚠ Rider not found. Copy Tools~/rider-live-templates.xml manually."
    fi
fi

if $VSCODE; then
    VSCODE_SNIPPETS="$HOME/.config/Code/User/snippets"
    [ -d "$HOME/Library/Application Support/Code/User/snippets" ] \
        && VSCODE_SNIPPETS="$HOME/Library/Application Support/Code/User/snippets"
    mkdir -p "$VSCODE_SNIPPETS"
    cp "$TOOLS/vscode-snippets.code-snippets" "$VSCODE_SNIPPETS/upm-package.code-snippets"
    echo "  ✓ VS Code snippets installed"
fi
