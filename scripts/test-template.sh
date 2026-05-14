#!/usr/bin/env bash
# ── Self-test: verify the template still works after changes ────
set -euo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' RESET=$'\033[0m'

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="/tmp/unity-template-selftest-$$"

echo ""
echo "  ${BOLD}Template self-test${RESET}"
echo "  Template: $TEMPLATE_ROOT"
echo "  Test dir: $TEST_DIR"
echo ""

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

# ── Check we're in the raw template (has __PLACEHOLDER__ files) ──

if [ ! -f "$TEMPLATE_ROOT/__PACKAGE__.Runtime/__PLACEHOLDER__.cs" ]; then
    echo "  ${RED}✗${RESET} Not running from raw template (no __PLACEHOLDER__ files)."
    echo "  Run this from the template repo before setup.sh is executed."
    exit 1
fi

# ── Create a test package from the template ─────────────────────

mkdir -p "$TEST_DIR"
cp -r "$TEMPLATE_ROOT" "$TEST_DIR/pkg"
cd "$TEST_DIR/pkg"

# Remove any existing git history
cd "$TEST_DIR/pkg"
rm -rf .git

# Run setup with CLI args (non-interactive)
bash setup.sh com.selftest.verify "Self Test" "CI Bot" "SelfTest.Verify" 2>&1 | tail -3

# ── Verify structure ────────────────────────────────────────────

echo ""
echo "  ${BOLD}Checking structure...${RESET}"

[ -d "com.selftest.verify.Runtime" ] && echo "  ${GREEN}✓${RESET} Runtime dir" || { echo "  ${RED}✗${RESET} Runtime dir"; exit 1; }
[ -d "com.selftest.verify.Tests" ]   && echo "  ${GREEN}✓${RESET} Tests dir"   || { echo "  ${RED}✗${RESET} Tests dir"; exit 1; }
[ -f "package.json" ]                && echo "  ${GREEN}✓${RESET} package.json" || { echo "  ${RED}✗${RESET} package.json"; exit 1; }
[ ! -f "setup.sh" ]                  && echo "  ${GREEN}✓${RESET} setup.sh erased" || { echo "  ${RED}✗${RESET} setup.sh still exists"; exit 1; }
[ ! -f "install.sh" ]               && echo "  ${GREEN}✓${RESET} install.sh erased" || { echo "  ${RED}✗${RESET} install.sh still exists"; exit 1; }
[ ! -f "AGENTS.md" ]                && echo "  ${GREEN}✓${RESET} AGENTS.md erased" || { echo "  ${RED}✗${RESET} AGENTS.md still exists"; exit 1; }

# ── Verify no placeholders ─────────────────────────────────────

echo ""
echo "  ${BOLD}Checking placeholders...${RESET}"

LEFTOVER=$(grep -rl '__[A-Z_]*__' \
    --include='*.cs' --include='*.json' --include='*.asmdef' \
    . 2>/dev/null | grep -v '/obj/' | grep -v '/bin/' | grep -v '.github/' || true)

if [ -z "$LEFTOVER" ]; then
    echo "  ${GREEN}✓${RESET} No unreplaced placeholders"
else
    echo "  ${RED}✗${RESET} Placeholders remain: $LEFTOVER"
    exit 1
fi

# ── Verify build ────────────────────────────────────────────────

echo ""
echo "  ${BOLD}Building...${RESET}"

if ! dotnet restore com.selftest.verify.slnx >/dev/null 2>&1; then
    echo "  ${RED}✗${RESET} Restore failed"
    exit 1
fi
echo "  ${GREEN}✓${RESET} dotnet restore"

if ! dotnet build com.selftest.verify.slnx -c Release --no-restore >/dev/null 2>&1; then
    echo "  ${RED}✗${RESET} Build failed"
    exit 1
fi
echo "  ${GREEN}✓${RESET} dotnet build"

# ── Verify tests ────────────────────────────────────────────────

echo ""
echo "  ${BOLD}Testing...${RESET}"

if ! dotnet test com.selftest.verify.slnx -c Release --no-build --verbosity quiet 2>&1 | grep -q "Passed!"; then
    echo "  ${RED}✗${RESET} Tests failed"
    exit 1
fi
echo "  ${GREEN}✓${RESET} dotnet test"

# ── Verify no DLL leak ──────────────────────────────────────────

LEAKS=$(find . -path '*/bin' -prune -o -path '*/obj' -prune -o -path './.git' -prune \
    -o -name 'Unity.Mathematics*.dll' -print 2>/dev/null || true)

if [ -z "$LEAKS" ]; then
    echo "  ${GREEN}✓${RESET} No DLL leak"
else
    echo "  ${RED}✗${RESET} DLL leak: $LEAKS"
    exit 1
fi

# ── Done ────────────────────────────────────────────────────────

echo ""
echo "  ${GREEN}${BOLD}✓ Template self-test passed${RESET}"
echo ""
