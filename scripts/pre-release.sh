#!/usr/bin/env bash
# Usage: bash scripts/pre-release.sh <version>
# Runs the full pre-release checklist. Must all pass before tagging.
set -uo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: bash scripts/pre-release.sh <version>"
    exit 1
fi

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' RESET=$'\033[0m'
PASS=0; FAIL=0; WARN=0

ok()   { ((PASS++)); echo "  ${GREEN}✓${RESET} $1"; }
fail() { ((FAIL++)); echo "  ${RED}✗${RESET} $1"; }
warn() { ((WARN++)); echo "  ${YELLOW}⚠${RESET} $1"; }

cd "$(git rev-parse --show-toplevel)"

echo ""
echo "  ${BOLD}Pre-release checklist for v$VERSION${RESET}"
echo ""

# 1. package.json version matches
PKG_VER=$(python3 -c "import json; print(json.load(open('package.json'))['version'])")
[ "$PKG_VER" = "$VERSION" ] \
    && ok "package.json version: $PKG_VER" \
    || fail "package.json version ($PKG_VER) ≠ $VERSION — run: bash scripts/version.sh $VERSION"

# 2. Tag does not already exist
git tag | grep -q "^v$VERSION$" \
    && fail "Tag v$VERSION already exists" \
    || ok "Tag v$VERSION not yet created"

# 3. Working tree is clean
[ -z "$(git status --porcelain)" ] \
    && ok "Working tree clean" \
    || fail "Uncommitted changes — commit or stash before releasing"

# 4. On main branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$BRANCH" = "main" ] \
    && ok "On main branch" \
    || warn "On branch $BRANCH (expected main)"

# 5. Build passes
dotnet build *.slnx -c Release --nologo -v quiet >/dev/null 2>&1 \
    && ok "Build passes" \
    || fail "Build failed"

# 6. Tests pass
dotnet test *.slnx -c Release --no-build --verbosity quiet >/dev/null 2>&1 \
    && ok "Tests pass" \
    || fail "Tests failed"

# 7. No breaking API changes (if baseline exists)
if [ -f artifacts/api/baseline.txt ]; then
    bash scripts/api-diff.sh >/dev/null 2>&1 \
        && ok "No breaking API changes" \
        || fail "Breaking API change detected — bump major version or update baseline"
else
    warn "No API baseline — run: bash scripts/api-surface.sh artifacts/api/baseline.txt"
fi

# 8. CHANGELOG.md has an entry for this version
grep -q "\[$VERSION\]" CHANGELOG.md 2>/dev/null \
    && ok "CHANGELOG.md has entry for $VERSION" \
    || fail "CHANGELOG.md missing entry for $VERSION — run: bash scripts/ai-changelog.sh $VERSION --apply"

# 9. No known vulnerabilities
bash scripts/audit-deps.sh >/dev/null 2>&1 \
    && ok "No vulnerable dependencies" \
    || warn "Vulnerable dependencies found — review before releasing"

# 10. Package size within budget
bash scripts/check-size.sh 500 >/dev/null 2>&1 \
    && ok "Package size within budget" \
    || fail "Package too large — review and remove unnecessary files"

# 11. UPM structure valid
bash scripts/validate-upm.sh >/dev/null 2>&1 \
    && ok "UPM structure valid" \
    || fail "UPM structure invalid"

echo ""
echo "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [ "$FAIL" -eq 0 ]; then
    echo "  ${GREEN}${BOLD}✓ All checks pass. Safe to release.${RESET}"
    echo ""
    echo "  Run:"
    echo "    git tag v$VERSION"
    echo "    git push origin main --tags"
else
    echo "  ${RED}${BOLD}✗ $FAIL checks failed. Do not release.${RESET}"
fi

echo "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
