#!/usr/bin/env bash
# ── Self-test: verify the template still works after changes ────
set -euo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' RESET=$'\033[0m'

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

if [ ! -f "$TEMPLATE_ROOT/__PACKAGE__/Runtime/__PLACEHOLDER__.cs" ]; then
    echo "  ${RED}✗${RESET} Not running from raw template (no __PLACEHOLDER__ files)."
    echo "  Run this from the template repo before setup.sh is executed."
    exit 1
fi

# ── Create a test package from the template ─────────────────────

mkdir -p "$TEST_DIR"
cp -r "$TEMPLATE_ROOT" "$TEST_DIR/pkg"
cd "$TEST_DIR/pkg"
rm -rf .git

# Run setup with CLI args (non-interactive)
bash setup.sh com.selftest.verify "Self Test" "SelfTestAuthor" "SelfTest.Verify" 2>&1 | tail -3

# ── Verify structure ────────────────────────────────────────────

echo ""
echo "  ${BOLD}Checking structure...${RESET}"

check() {
    if [ "$1" = "exists" ] && [ -e "$2" ]; then
        echo "  ${GREEN}✓${RESET} $2"
    elif [ "$1" = "missing" ] && [ ! -e "$2" ]; then
        echo "  ${GREEN}✓${RESET} $2 (erased)"
    else
        echo "  ${RED}✗${RESET} $2 ($1 check failed)"
        exit 1
    fi
}

check exists "com.selftest.verify"
check exists "com.selftest.verify/Runtime"
check exists "com.selftest.verify/Tests"
check exists "com.selftest.verify/Editor"
check exists "package.json"
check exists "README.md"
check exists "LICENSE"
check exists "scripts/smoke.sh"
check exists "scripts/doctor.sh"
check exists "scripts/validate-upm.sh"
check exists "scripts/version.sh"
check missing "scripts/test-template.sh"
check missing "scripts/test-cli.sh"
check exists "com.selftest.verify.slnx"
check missing "setup.sh"
check missing "install.sh"
check missing "AGENTS.md"
check missing "CHANGELOG.md"
check missing "TODO-FEATURES.md"

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

# ── Verify scripts ──────────────────────────────────────────────

echo ""
echo "  ${BOLD}Checking scripts...${RESET}"

# doctor.sh — should run without crashing (warnings ok in CI)
if bash scripts/doctor.sh >/dev/null 2>&1; then
    echo "  ${GREEN}✓${RESET} doctor.sh (all pass)"
elif bash scripts/doctor.sh 2>&1 | grep -qE '(checks pass|ok,)'; then
    echo "  ${GREEN}✓${RESET} doctor.sh (partial — expected in CI)"
else
    echo "  ${YELLOW}⚠${RESET} doctor.sh warnings (ok in CI)"
fi

# validate-upm.sh should pass
if bash scripts/validate-upm.sh 2>&1 | grep -q "Package is valid"; then
    echo "  ${GREEN}✓${RESET} validate-upm.sh"
else
    echo "  ${RED}✗${RESET} validate-upm.sh failed"
    exit 1
fi

# ── Done ────────────────────────────────────────────────────────

echo ""
echo "  ${GREEN}${BOLD}✓ Template self-test passed${RESET}"
echo ""
