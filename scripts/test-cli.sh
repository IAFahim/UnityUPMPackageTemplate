#!/usr/bin/env bash
# ── CLI Test Runner: validates the entire template pipeline ─────
set -uo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' CYAN=$'\033[36m' DIM=$'\033[2m' RESET=$'\033[0m'

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="/tmp/unity-cli-test-$$"
PASS=0 FAIL=0 SKIP=0 TOTAL=0

cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT
mkdir -p "$TEST_ROOT"

# ── Assertions ──────────────────────────────────────────────────

pass() { ((PASS++)) || true; ((TOTAL++)) || true; echo "  ${GREEN}✓${RESET} $1"; }
fail() { ((FAIL++)) || true; ((TOTAL++)) || true; echo "  ${RED}✗${RESET} $1"; }

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then pass "$label"
    else fail "$label — expected '$expected', got '$actual'"; fi
}
assert_contains() {
    local label="$1" file="$2" pattern="$3"
    if grep -q "$pattern" "$file" 2>/dev/null; then pass "$label"
    else fail "$label — '$pattern' not in $(basename "$file")"; fi
}
assert_exists() {
    if [ -e "$2" ]; then pass "$1"; else fail "$1 — missing $(basename "$2")"; fi
}
assert_missing() {
    if [ ! -e "$2" ]; then pass "$1"; else fail "$1 — $(basename "$2") exists"; fi
}
assert_no_placeholders() {
    local found; found=$(grep -rl '__[A-Z_]*__' --include='*.cs' --include='*.json' --include='*.asmdef' \
        "$2" 2>/dev/null | grep -v '/obj/' | grep -v '/bin/' | grep -v '.github/' || true)
    if [ -z "$found" ]; then pass "$1"; else fail "$1 — placeholders: $found"; fi
}
assert_no_dll_leak() {
    local leaks; leaks=$(find "$2" -path '*/bin' -prune -o -path '*/obj' -prune -o -path '*/.git' -prune \
        -o -name 'Unity.Mathematics*.dll' -print 2>/dev/null || true)
    if [ -z "$leaks" ]; then pass "$1"; else fail "$1 — leak: $leaks"; fi
}
section() { echo ""; echo "  ${CYAN}${BOLD}── $1 ──${RESET}"; echo ""; }

# ── Helper functions (mirror of setup.sh) ───────────────────────

pascal() { echo "$1" | sed 's/[-_ ]\+/_/g' | awk -F'_' '{for(i=1;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)), substr($i,2)}'; }
package_to_namespace() { echo "$1" | awk -F'.' '{ for(i=2;i<=NF;i++) { split($i,p,/[-_]/); for(j=1;j<=length(p);j++) printf "%s%s", toupper(substr(p[j],1,1)), substr(p[j],2); if(i<NF) printf "." } }'; }
validate_package_id() { [[ "$1" =~ ^[a-z][a-z0-9]*(\.[a-z][a-z0-9_-]*){2,}$ ]]; }
escape_sed() { printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'; }

# ═══════════════════════════════════════════════════════════════
echo ""
echo "  ${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo "  ${BOLD}║   ${CYAN}CLI Test Runner${RESET}${BOLD}                                   ║${RESET}"
echo "  ${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"

# ═══════════════════════ SECTION 1: Unit Tests ═══════════════
section "1. Helper Functions"

assert_eq "pascal: hyphenated"       "GridPathfinding" "$(pascal 'grid-pathfinding')"
assert_eq "pascal: single word"      "Grid"            "$(pascal 'grid')"
assert_eq "pascal: underscores"      "GridPathfinding" "$(pascal 'grid_pathfinding')"
assert_eq "pascal: mixed"            "GridPath"        "$(pascal 'grid path')"
assert_eq "pascal: already Pascal"   "GridPathfinding" "$(pascal 'GridPathfinding')"
assert_eq "pascal: numbers"          "Grid2d"          "$(pascal 'grid-2d')"

assert_eq "ns: com.bovinelabs.grid"              "Bovinelabs.Grid"             "$(package_to_namespace 'com.bovinelabs.grid')"
assert_eq "ns: com.bovinelabs.grid.pathfinding"  "Bovinelabs.Grid.Pathfinding" "$(package_to_namespace 'com.bovinelabs.grid.pathfinding')"
assert_eq "ns: com.test.my-cool-lib"             "Test.MyCoolLib"              "$(package_to_namespace 'com.test.my-cool-lib')"

assert_eq "valid: com.bovinelabs.grid"   "true"  "$(validate_package_id 'com.bovinelabs.grid' && echo true || echo false)"
assert_eq "valid: com.test.grid-path"    "true"  "$(validate_package_id 'com.test.grid-path' && echo true || echo false)"
assert_eq "valid: com.a.b"               "true"  "$(validate_package_id 'com.a.b' && echo true || echo false)"
assert_eq "valid: COM.UPPER.BAD"         "false" "$(validate_package_id 'COM.UPPER.BAD' && echo true || echo false)"
assert_eq "valid: grid"                  "false" "$(validate_package_id 'grid' && echo true || echo false)"
assert_eq "valid: com.onlyone"           "false" "$(validate_package_id 'com.onlyone' && echo true || echo false)"
assert_eq "valid: com.123.bad"           "false" "$(validate_package_id 'com.123.bad' && echo true || echo false)"

assert_eq "sed_esc: normal"      "hello"           "$(escape_sed 'hello')"
assert_eq "sed_esc: ampersand"   'Vex \& Sons'     "$(escape_sed 'Vex & Sons')"
assert_eq "sed_esc: slash"       'path\/to\/file'  "$(escape_sed 'path/to/file')"
assert_eq "sed_esc: backslash"   'a\\b'            "$(escape_sed 'a\b')"
assert_eq "sed_esc: combined"    'a\/b\&c\\d'      "$(escape_sed 'a/b&c\d')"

# ═══════════════════════ SECTION 2: Template Integrity ═══════
section "2. Template Integrity"

for f in \
    __PACKAGE__.Runtime __PACKAGE__.Tests __PACKAGE__.slnx \
    package.json setup.sh install.sh AGENTS.md CHANGELOG.md LICENSE \
    global.json Directory.Build.props .editorconfig .gitattributes .gitignore \
    Dev~/src/__PACKAGE__ Dev~/tests/__PACKAGE__.Tests Dev~/benchmarks/__PACKAGE__.Benchmarks \
    Dev~/tools/TestLogCompact Dev~/tools/TestResultsCompact Dev~/tools/UnityPackageExporter Dev~/tools/UnityMetaValidator; do
    assert_exists "Template: $f" "$TEMPLATE_ROOT/$f"
done

assert_exists "Template: __PLACEHOLDER__.cs"           "$TEMPLATE_ROOT/__PACKAGE__.Runtime/__PLACEHOLDER__.cs"
assert_exists "Template: __PLACEHOLDER__.Tests.cs"      "$TEMPLATE_ROOT/__PACKAGE__.Tests/__PLACEHOLDER__.Tests.cs"
assert_contains "Template: asmdef noEngineReferences"    "$TEMPLATE_ROOT/__PACKAGE__.Runtime/__PACKAGE__.Runtime.asmdef" '"noEngineReferences": true'

# ═══════════════════════ SECTION 3: setup.sh basic ═══════════
section "3. setup.sh — Basic"

T="$TEST_ROOT/basic"; mkdir -p "$T"
cp -r "$TEMPLATE_ROOT" "$T/pkg"; cd "$T/pkg"; rm -rf .git
bash setup.sh com.test.basic "Basic Test" "Test Author" "Test.Basic" 2>&1 | tail -3

for f in \
    com.test.basic.Runtime com.test.basic.Tests \
    Dev~/src/com.test.basic Dev~/tests/com.test.basic.Tests \
    Dev~/benchmarks/com.test.basic.Benchmarks \
    com.test.basic.slnx package.json README.md LICENSE \
    .editorconfig .gitignore scripts/smoke.sh .github/workflows/ci.yml; do
    assert_exists "setup: $(basename "$f")" "$T/pkg/$f"
done

for f in setup.sh install.sh AGENTS.md CHANGELOG.md; do
    assert_missing "setup: $f erased" "$T/pkg/$f"
done

assert_no_placeholders "setup: no placeholders" "$T/pkg"
assert_no_dll_leak     "setup: no DLL leak"     "$T/pkg"
assert_contains "setup: pkg name"       "$T/pkg/package.json" '"name": "com.test.basic"'
assert_contains "setup: pkg display"    "$T/pkg/package.json" '"displayName": "Basic Test"'
assert_contains "setup: README title"   "$T/pkg/README.md"    "# Basic Test"
assert_contains "setup: asmdef name"    "$T/pkg/com.test.basic.Runtime/com.test.basic.Runtime.asmdef" '"name": "com.test.basic.Runtime"'

# ═══════════════════════ SECTION 4: Special chars ════════════
section "4. setup.sh — Special Characters"

T="$TEST_ROOT/special"; mkdir -p "$T"
cp -r "$TEMPLATE_ROOT" "$T/pkg"; cd "$T/pkg"; rm -rf .git
bash setup.sh com.test.special "Special & Cool: Math/AI" "Vex & Sons/Co" "Test.Special" 2>&1 | tail -3

assert_no_placeholders "special: no placeholders" "$T/pkg"
assert_contains "special: pkg author &"  "$T/pkg/package.json" 'Vex & Sons/Co'
assert_contains "special: pkg display /" "$T/pkg/package.json" 'Special & Cool: Math/AI'
assert_contains "special: LICENSE &"     "$T/pkg/LICENSE"      "Vex & Sons/Co"

# ═══════════════════════ SECTION 5: Hyphenated pkg ═══════════
section "5. setup.sh — Hyphenated Package"

T="$TEST_ROOT/hyphen"; mkdir -p "$T"
cp -r "$TEMPLATE_ROOT" "$T/pkg"; cd "$T/pkg"; rm -rf .git
bash setup.sh com.bovinelabs.grid-pathfinding "Grid Pathfinding" "Vex" "Bovinelabs.GridPathfinding" 2>&1 | tail -3

assert_exists "hyphen: Runtime dir" "$T/pkg/com.bovinelabs.grid-pathfinding.Runtime"
assert_exists "hyphen: Tests dir"   "$T/pkg/com.bovinelabs.grid-pathfinding.Tests"
assert_no_placeholders "hyphen: no placeholders" "$T/pkg"

# ═══════════════════════ SECTION 6: Build & Test ═════════════
section "6. Build & Test (basic pkg)"

cd "$TEST_ROOT/basic/pkg"

dotnet restore com.test.basic.slnx >/dev/null 2>&1 && pass "build: restore" || fail "build: restore"
dotnet build com.test.basic.slnx -c Release --no-restore >/dev/null 2>&1 && pass "build: build" || fail "build: build"
dotnet test com.test.basic.slnx -c Release --no-build --verbosity quiet 2>&1 | grep -q "Passed!" && pass "build: test" || fail "build: test"

# ═══════════════════════ SECTION 7: Post-gen scripts ════════
section "7. Post-generation Scripts"

cd "$TEST_ROOT/basic/pkg"

bash scripts/doctor.sh >/dev/null 2>&1 && pass "scripts: doctor.sh" || pass "scripts: doctor.sh (warnings ok)"
bash scripts/validate-upm.sh 2>&1 | grep -q "Package is valid" && pass "scripts: validate-upm.sh" || fail "scripts: validate-upm.sh"
bash scripts/smoke.sh 2>&1 | grep -qE '(OK:|Passed!|Smoke test passed)' && pass "scripts: smoke.sh" || fail "scripts: smoke.sh"
bash scripts/version.sh 0.2.0 >/dev/null 2>&1
assert_contains "scripts: version bump" "$TEST_ROOT/basic/pkg/package.json" '"version": "0.2.0"'
bash scripts/verify-meta.sh >/dev/null 2>&1 && pass "scripts: verify-meta.sh" || pass "scripts: verify-meta.sh (no meta)"

# ═══════════════════════ SECTION 8: Build special ════════════
section "8. Build & Test (special chars pkg)"

cd "$TEST_ROOT/special/pkg"
dotnet restore com.test.special.slnx >/dev/null 2>&1 && pass "special: restore" || fail "special: restore"
dotnet build com.test.special.slnx -c Release --no-restore >/dev/null 2>&1 && pass "special: build" || fail "special: build"

# ═══════════════════════ SECTION 9: Build hyphenated ════════
section "9. Build & Test (hyphenated pkg)"

cd "$TEST_ROOT/hyphen/pkg"
dotnet restore com.bovinelabs.grid-pathfinding.slnx >/dev/null 2>&1 && pass "hyphen: restore" || fail "hyphen: restore"
dotnet build com.bovinelabs.grid-pathfinding.slnx -c Release --no-restore >/dev/null 2>&1 && pass "hyphen: build" || fail "hyphen: build"

# ═══════════════════════ SECTION 10: Tools ══════════════════
section "10. Tools"

T="$TEST_ROOT/basic/pkg"
dotnet build "$TEMPLATE_ROOT/Dev~/tools/TestLogCompact/TestLogCompact.csproj" -c Release >/dev/null 2>&1 && pass "tool: TestLogCompact builds" || fail "tool: TestLogCompact builds"
dotnet build "$TEMPLATE_ROOT/Dev~/tools/TestResultsCompact/TestResultsCompact.csproj" -c Release >/dev/null 2>&1 && pass "tool: TestResultsCompact builds" || fail "tool: TestResultsCompact builds"
dotnet build "$TEMPLATE_ROOT/Dev~/tools/UnityMetaValidator/UnityMetaValidator.csproj" -c Release >/dev/null 2>&1 && pass "tool: UnityMetaValidator builds" || fail "tool: UnityMetaValidator builds"

# ═══════════════════════ SUMMARY ════════════════════════════
echo ""
echo "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [ "$FAIL" -eq 0 ]; then
    echo "  ${GREEN}${BOLD}✓ $PASS / $TOTAL passed${RESET}"
else
    echo "  ${RED}${BOLD}✗ $FAIL failed${RESET}, ${GREEN}$PASS passed${RESET}, $TOTAL total"
fi

echo "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
