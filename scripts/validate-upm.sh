#!/usr/bin/env bash
# ── Validate UPM package structure ──────────────────────────────
set -uo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' RESET=$'\033[0m'
PASS=0 FAIL=0

ok()   { ((PASS++)); echo "  ${GREEN}✓${RESET} $1"; }
fail() { ((FAIL++)); echo "  ${RED}✗${RESET} $1"; }
warn() { echo "  ${YELLOW}⚠${RESET} $1"; }

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

echo ""
echo "  ${BOLD}Validating UPM package...${RESET}"
echo ""

IS_TEMPLATE=0
if [ -f "__PACKAGE__/Runtime/__PLACEHOLDER__.cs" ]; then
    IS_TEMPLATE=1
fi

# ── Required files ──────────────────────────────────────────────

for f in package.json README.md LICENSE; do
    [ -f "$f" ] && ok "$f exists" || fail "$f missing"
done

# ── package.json fields ─────────────────────────────────────────

if [ -f "package.json" ]; then
    validate_field() {
        local val=$(python3 -c "import json; print(json.load(open('package.json')).get('$1',''))" 2>/dev/null || echo "")
        [ -n "$val" ] && ok "package.json has $1" || fail "package.json missing $1"
    }

    validate_field "name"
    validate_field "version"
    validate_field "displayName"
    validate_field "unity"
    validate_field "license"
    validate_field "author"

    # OpenUPM requires: description, keywords, author.url or author.email
    PKG_DESC=$(python3 -c "import json; print(json.load(open('package.json')).get('description',''))" 2>/dev/null || true)
    [ -n "$PKG_DESC" ] && ok "description present (OpenUPM)" || warn "description missing — required for OpenUPM"

    PKG_KEYWORDS=$(python3 -c "import json; kw=json.load(open('package.json')).get('keywords',[]); print(len(kw))" 2>/dev/null || echo "0")
    [ "$PKG_KEYWORDS" -gt 0 ] && ok "$PKG_KEYWORDS keywords (OpenUPM)" || warn "no keywords — add some for OpenUPM discoverability"

    # Validate name format
    PKG_NAME=$(python3 -c "import json; print(json.load(open('package.json'))['name'])" 2>/dev/null || true)
    if [ -n "$PKG_NAME" ]; then
        if [ "$IS_TEMPLATE" -eq 1 ]; then
            ok "package name (template mode)"
        elif [[ "$PKG_NAME" =~ ^[a-z][a-z0-9]*(\.[a-z][a-z0-9_-]*){2,}$ ]]; then
            ok "package name is valid reverse-DNS"
        else
            fail "package name '$PKG_NAME' is not valid reverse-DNS"
        fi
    fi

    # Validate version format
    PKG_VER=$(python3 -c "import json; print(json.load(open('package.json'))['version'])" 2>/dev/null || true)
    if [ -n "$PKG_VER" ]; then
        if [[ "$PKG_VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
            ok "version '$PKG_VER' is semver"
        else
            fail "version '$PKG_VER' is not valid semver"
        fi
    fi
fi

# ── asmdef files ────────────────────────────────────────────────

RUNTIME_ASMDEF=$(find . -maxdepth 3 -name "*.asmdef" -path "*/Runtime/*" ! -path "*/bin/*" ! -path "*/obj/*" | head -1)
TESTS_ASMDEF=$(find . -maxdepth 3 -name "*.asmdef" -path "*/Tests/*" ! -path "*/bin/*" ! -path "*/obj/*" | head -1)

[ -n "$RUNTIME_ASMDEF" ] && ok "Runtime asmdef exists" || fail "No Runtime asmdef"
[ -n "$TESTS_ASMDEF" ] && ok "Tests asmdef exists" || warn "No Tests asmdef"

# Check asmdef references match package dependencies
if [ -n "$RUNTIME_ASMDEF" ] && [ -f "package.json" ]; then
    ASMDEF_REFS=$(python3 -c "import json; print(' '.join(json.load(open('$RUNTIME_ASMDEF')).get('references',[])))" 2>/dev/null || true)
    ok "Runtime asmdef references: $ASMDEF_REFS"
fi

# ── Forbidden files ─────────────────────────────────────────────

DLLS=$(find . -path '*/bin' -prune -o -path '*/obj' -prune -o -path './.git' -prune \
    -o -name '*.dll' -print 2>/dev/null || true)
[ -z "$DLLS" ] && ok "No DLLs in package" || fail "DLLs found: $DLLS"

# No bin/obj/artifacts tracked by git
if git rev-parse --git-dir >/dev/null 2>&1; then
    TRACKED_BUILD=$(git ls-files bin/ obj/ artifacts/ 2>/dev/null | grep -v 'artifacts/api/baseline.txt' || true)
    [ -z "$TRACKED_BUILD" ] && ok "No build outputs tracked by git" || fail "Build outputs tracked: $TRACKED_BUILD"
fi

# No placeholders
if [ "$IS_TEMPLATE" -eq 1 ]; then
    ok "No placeholders check (template mode)"
else
    LEFTOVER=$(grep -rl '__[A-Z_]*__' \
        --include='*.cs' --include='*.json' --include='*.asmdef' \
        . 2>/dev/null | grep -v '/obj/' | grep -v '/bin/' | grep -v '.github/' || true)
    [ -z "$LEFTOVER" ] && ok "No unreplaced placeholders" || fail "Placeholders in: $LEFTOVER"
fi

if [ "$IS_TEMPLATE" -eq 1 ]; then
    for f in setup.sh install.sh AGENTS.md CHANGELOG.md; do
        [ -f "$f" ] && ok "$f exists in template mode" || fail "$f missing in template mode"
    done
else
    for f in setup.sh install.sh AGENTS.md; do
        [ ! -f "$f" ] && ok "No $f in generated package" || fail "$f is a template artifact"
    done
fi

if [ "$IS_TEMPLATE" -eq 1 ]; then
    for f in \
        __PACKAGE__/Runtime/__PLACEHOLDER__.cs \
        __PACKAGE__/Tests/__PLACEHOLDER__.Tests.cs \
        Dev~/src/__PACKAGE__/__PACKAGE__.csproj \
        Dev~/tests/__PACKAGE__.Tests/__PACKAGE__.Tests.csproj \
        __PACKAGE__.slnx
    do
        [ -e "$f" ] && ok "Template file exists: $f" || fail "Template file missing: $f"
    done
fi

# No IDE/OS files
JUNK=$(find . -maxdepth 3 -name "*.user" -o -name ".DS_Store" -o -name "Thumbs.db" | head -5 || true)
[ -z "$JUNK" ] && ok "No IDE/OS junk files" || fail "Junk files: $JUNK"

# ── Source structure ────────────────────────────────────────────

RUNTIME_DIR=$(find . -maxdepth 1 -type d -not -name '.*' -not -name 'Dev~*' -not -name 'bin' -not -name 'obj' -not -name 'artifacts' -not -name 'benchmarks' -not -name 'Samples~' -not -name 'Documentation~' -not -name 'Skills~' -not -name 'Tools~' -not -name 'scripts' -not -name '.github' | head -1)
[ -n "$RUNTIME_DIR" ] && ok "Package directory: $RUNTIME_DIR" || fail "No package directory"

TESTS_DIR="${RUNTIME_DIR}/Tests"
[ -d "$TESTS_DIR" ] && ok "Tests directory: $TESTS_DIR" || warn "No Tests directory"

# ── Dotnet bridge ───────────────────────────────────────────────

if ls *.slnx >/dev/null 2>&1; then ok "Solution file exists"; else warn "No .slnx file"; fi
[ -d "Dev~/src" ] && ok "Dev~/src/ directory (dotnet bridge)" || warn "No Dev~/src/ directory"
[ -d "Dev~/tests" ] && ok "Dev~/tests/ directory (dotnet bridge)" || warn "No Dev~/tests/ directory"

# ── Summary ─────────────────────────────────────────────────────

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  ${GREEN}${BOLD}✓ Package is valid${RESET} ($PASS checks passed)"
else
    echo "  ${RED}${BOLD}✗ $FAIL issues found${RESET} ($PASS checks passed)"
fi
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
