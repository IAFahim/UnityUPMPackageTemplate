#!/usr/bin/env bash
# ── Smoke test: build, test, and validate structure ─────────────
set -uo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' RESET=$'\033[0m'

echo ""
echo "  ${BOLD}Running smoke tests...${RESET}"
echo ""

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

# ── Build & Test ────────────────────────────────────────────────

if ! dotnet restore *.slnx >/dev/null 2>&1; then echo "  ${RED}✗${RESET} Restore failed"; exit 1; fi
echo "  ${GREEN}✓${RESET} dotnet restore"

if ! dotnet build *.slnx -c Release --no-restore >/dev/null 2>&1; then echo "  ${RED}✗${RESET} Build failed"; exit 1; fi
echo "  ${GREEN}✓${RESET} dotnet build"

mkdir -p artifacts/coverage
if ! dotnet test *.slnx -c Release --no-build \
    --collect:"XPlat Code Coverage" \
    --results-directory artifacts/coverage \
    --verbosity quiet >artifacts/coverage/run.log 2>&1; then
    echo "  ${RED}✗${RESET} Tests failed"
    exit 1
fi
echo "  ${GREEN}✓${RESET} dotnet test"

COVERAGE=$(python3 - <<'PY'
import glob, xml.etree.ElementTree as ET, os
files = glob.glob("artifacts/coverage/**/*.xml", recursive=True)
if not files:
    print("?")
    exit()
tree = ET.parse(files[0])
cov = tree.find(".//coverage")
pct = float(cov.get("line-rate","0")) * 100 if cov is not None else 0
print(f"{pct:.0f}")
PY
)
echo "  Coverage: $COVERAGE%"

# ── API Diff ────────────────────────────────────────────────────

if bash scripts/api-diff.sh 2>/dev/null; then
    echo "  ${GREEN}✓${RESET} API surface (no breaking changes)"
else
    YELLOW=$'\033[33m'
    echo "  ${YELLOW}⚠${RESET} API surface changed — see artifacts/api/"
fi

# ── Validations ─────────────────────────────────────────────────

if bash scripts/validate-upm.sh >/dev/null 2>&1; then
    echo "  ${GREEN}✓${RESET} UPM structure valid"
else
    echo "  ${RED}✗${RESET} UPM structure invalid (run scripts/validate-upm.sh for details)"
    exit 1
fi

if bash scripts/verify-meta.sh >/dev/null 2>&1; then
    echo "  ${GREEN}✓${RESET} Metadata integrity valid"
else
    echo "  ${RED}✗${RESET} Metadata integrity invalid (run scripts/verify-meta.sh for details)"
    exit 1
fi

# ── DLL leak ───────────────────────────────────────────────────

LEAKS=$(find . -path '*/bin' -prune -o -path '*/obj' -prune -o -path './.git' -prune \
    -o -name 'Unity.Mathematics*.dll' -print 2>/dev/null)
if [ -n "$LEAKS" ]; then
    echo "  ${RED}✗${RESET} Unity.Mathematics DLL leak found!"
    echo "$LEAKS"
    exit 1
fi
echo "  ${GREEN}✓${RESET} No DLL leak"

echo ""
echo "  ${GREEN}${BOLD}✓ Smoke test passed${RESET}"
echo ""
