#!/usr/bin/env bash
# ── Install optional local developer helpers ────────────────────
set -uo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' YELLOW=$'\033[33m' DIM=$'\033[2m' RESET=$'\033[0m'

echo ""
echo "  ${BOLD}Dev Tools Installer${RESET}"
echo ""

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

# ── Prerequisite check ──────────────────────────────────────────

check_tool() {
    if command -v "$1" >/dev/null 2>&1; then
        echo "  ${GREEN}✓${RESET} $1 installed"
        return 0
    else
        echo "  ${YELLOW}⊘${RESET} $1 missing"
        return 1
    fi
}

check_tool "dotnet" || echo "  ${DIM}Install .NET SDK: https://dotnet.microsoft.com/download${RESET}"
check_tool "gh"     || echo "  ${DIM}Install GitHub CLI: https://cli.github.com${RESET}"
check_tool "npm"    || echo "  ${DIM}Install Node.js: https://nodejs.org${RESET}"

echo ""

# ── .NET Tool Manifest ──────────────────────────────────────────

if command -v dotnet >/dev/null 2>&1; then
    if [ ! -f ".config/dotnet-tools.json" ]; then
        echo "  ${GREEN}►${RESET} Creating .NET tool manifest..."
        dotnet new tool-manifest 2>/dev/null
    fi
    echo "  ${GREEN}✓${RESET} .NET tool manifest ready"
fi

# ── Optional GC AI Context ──────────────────────────────────────

echo ""
echo "  ${BOLD}AI Context Tool${RESET}"
if command -v npm >/dev/null 2>&1; then
    echo "  ${DIM}Use 'npx @iafahim/gc' to generate codebase context for LLMs.${RESET}"
else
    echo "  ${YELLOW}⚠${RESET} npm not found — cannot run @iafahim/gc via npx."
fi

# ── Project Tools ───────────────────────────────────────────────

echo ""
echo "  ${BOLD}Project-specific tools (in tools/ folder)${RESET}"
echo "  These can be run using 'dotnet run --project tools/<ToolName>':"
echo ""

for tool in tools/*/; do
    [ -d "$tool" ] || continue
    name=$(basename "$tool")
    echo "  - ${BOLD}$name${RESET}"
done

echo ""
echo "  Example:"
echo "    ${DIM}dotnet run --project tools/UnityMetaValidator -- ./Runtime${RESET}"
echo ""

echo "  Done."
echo ""
