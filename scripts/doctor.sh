#!/usr/bin/env bash
# ── Doctor: diagnose your Unity package environment ─────────────
set -uo pipefail

# Don't exit on non-zero — we handle errors ourselves
# set -e breaks grep/find that return non-zero when nothing matches

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' DIM=$'\033[2m' RESET=$'\033[0m'
PASS=0 FAIL=0 WARN=0

ok()   { ((PASS++)); echo "  ${GREEN}✓${RESET} $1"; }
fail() { ((FAIL++)); echo "  ${RED}✗${RESET} $1"; }
warn() { ((WARN++)); echo "  ${YELLOW}⚠${RESET} $1"; }

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

echo ""
echo "  ${BOLD}Running diagnostics...${RESET}"
echo ""

# ── Toolchain ───────────────────────────────────────────────────

if command -v dotnet >/dev/null 2>&1; then
    ok ".NET SDK $(dotnet --version 2>/dev/null)"
else
    fail ".NET SDK not found"
fi

if command -v git >/dev/null 2>&1; then
    ok "git $(git --version 2>/dev/null | awk '{print $3}')"
else
    fail "git not found"
fi

if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
        ok "gh CLI authenticated as $(gh api user -q .login 2>/dev/null)"
    else
        warn "gh CLI installed but not authenticated"
    fi
else
    warn "gh CLI not found (GitHub push won't work)"
fi

if command -v python3 >/dev/null 2>&1; then
    ok "python3 available"
else
    warn "python3 not found (CI cleanup fallback)"
fi

# ── Git config ──────────────────────────────────────────────────

GIT_USER=$(git config user.name 2>/dev/null || true)
GIT_EMAIL=$(git config user.email 2>/dev/null || true)
[ -n "$GIT_USER" ]  && ok "git user.name: $GIT_USER"  || fail "git user.name not set"
[ -n "$GIT_EMAIL" ] && ok "git user.email: $GIT_EMAIL" || fail "git user.email not set"

# ── Unity ───────────────────────────────────────────────────────

UNITY_HUB="$HOME/Unity/Hub/Editor"
if [ -d "$UNITY_HUB" ]; then
    COUNT=$(ls -1d "$UNITY_HUB"/*/ 2>/dev/null | wc -l)
    if [ "$COUNT" -gt 0 ]; then
        VERSIONS=""
        for d in "$UNITY_HUB"/*/; do
            VERSIONS="$VERSIONS $(basename "$d")"
        done
        ok "Unity editors ($COUNT):$VERSIONS"
    else
        warn "Unity Hub folder exists but no editors installed"
    fi
else
    warn "Unity Hub not found at $UNITY_HUB"
fi

# ── Package structure ───────────────────────────────────────────

IS_TEMPLATE=0
if [ -f "__PACKAGE__.Runtime/__PLACEHOLDER__.cs" ]; then
    IS_TEMPLATE=1
fi

if [ -f "package.json" ]; then
    ok "package.json exists"

    PKG_NAME=$(python3 -c "import json; print(json.load(open('package.json'))['name'])" 2>/dev/null || true)
    PKG_VER=$(python3 -c "import json; print(json.load(open('package.json'))['version'])" 2>/dev/null || true)
    PKG_UNITY=$(python3 -c "import json; print(json.load(open('package.json')).get('unity',''))" 2>/dev/null || true)
    PKG_LICENSE=$(python3 -c "import json; print(json.load(open('package.json')).get('license',''))" 2>/dev/null || true)

    [ -n "$PKG_NAME" ] && ok "package name: $PKG_NAME" || fail "package name missing"
    [ -n "$PKG_VER" ]  && ok "package version: $PKG_VER" || fail "package version missing"
    [ -n "$PKG_UNITY" ] && ok "unity minimum: $PKG_UNITY" || warn "unity field missing"
    [ -n "$PKG_LICENSE" ] && ok "license: $PKG_LICENSE" || warn "license field missing"

    # Validate reverse-DNS
    if [ "$IS_TEMPLATE" -eq 0 ] && [ -n "$PKG_NAME" ] && [[ ! "$PKG_NAME" =~ ^[a-z][a-z0-9]*(\.[a-z][a-z0-9_-]*){2,}$ ]]; then
        fail "package name '$PKG_NAME' is not valid reverse-DNS"
    fi
else
    fail "package.json not found — not in a package root?"
fi

# Runtime asmdef
RUNTIME_ASMDEF=$(find . -maxdepth 2 -name "*.Runtime.asmdef" ! -path "*/bin/*" ! -path "*/obj/*" | head -1)
if [ -n "$RUNTIME_ASMDEF" ]; then
    ok "Runtime asmdef: $(basename "$RUNTIME_ASMDEF")"
    # Check noEngineReferences
    NO_ENGINE=$(python3 -c "import json; print(json.load(open('$RUNTIME_ASMDEF')).get('noEngineReferences', False))" 2>/dev/null || echo "False")
    if [ "$NO_ENGINE" = "True" ]; then
        ok "Runtime asmdef has noEngineReferences=true"
    else
        warn "Runtime asmdef noEngineReferences not set — runtime may pull in UnityEngine"
    fi
else
    fail "No Runtime asmdef found"
fi

# Tests asmdef
TESTS_ASMDEF=$(find . -maxdepth 2 -name "*.Tests.asmdef" ! -path "*/bin/*" ! -path "*/obj/*" | head -1)
[ -n "$TESTS_ASMDEF" ] && ok "Tests asmdef: $(basename "$TESTS_ASMDEF")" || warn "No Tests asmdef found"

# ── Source files ────────────────────────────────────────────────

RUNTIME_DIR=$(find . -maxdepth 1 -type d -name "*.Runtime" | head -1)
if [ -n "$RUNTIME_DIR" ]; then
    CS_COUNT=$(find "$RUNTIME_DIR" -name "*.cs" ! -path "*/bin/*" ! -path "*/obj/*" 2>/dev/null | wc -l)
    ok "Runtime has $CS_COUNT .cs files"
else
    fail "No *.Runtime directory found"
fi

# ── Dotnet projects ─────────────────────────────────────────────

if ls *.slnx >/dev/null 2>&1; then
    ok "Solution file: $(ls *.slnx)"
else
    warn "No .slnx file found"
fi

if [ -d "Dev~/src" ]; then
    SRC_CSPROJ=$(find Dev~/src -name "*.csproj" | head -1)
    if [ -n "$SRC_CSPROJ" ]; then
        ok "src project: $(basename "$SRC_CSPROJ")"
        # Check compile includes point at Runtime
        if grep -q "Runtime" "$SRC_CSPROJ" 2>/dev/null; then
            ok "src csproj links to Runtime/"
        else
            warn "src csproj doesn't reference Runtime/ folder"
        fi
        # Check assembly name matches asmdef
        ASM_NAME=$(grep -oP 'AssemblyName>\K[^<]+' "$SRC_CSPROJ" 2>/dev/null || true)
        ASMDEF_NAME=$(python3 -c "import json; print(json.load(open('$RUNTIME_ASMDEF'))['name'])" 2>/dev/null || true)
        if [ -n "$ASM_NAME" ] && [ -n "$ASMDEF_NAME" ]; then
            if [ "$ASM_NAME" = "$ASMDEF_NAME" ]; then
                ok "Assembly name ($ASM_NAME) matches asmdef"
            else
                fail "Assembly name '$ASM_NAME' ≠ asmdef name '$ASMDEF_NAME'"
            fi
        fi
    fi
fi

# ── Dependency hygiene ──────────────────────────────────────────

# Unity.Mathematics version alignment
if [ -f "Directory.Build.props" ]; then
    MATH_VER=$(grep -oP 'UnityMathematicsVersion>\K[^<]+' Directory.Build.props 2>/dev/null || true)
    if [ -n "$MATH_VER" ]; then
        ok "UnityMathematics version (Directory.Build.props): $MATH_VER"
    fi

    # Check no PackageReference in Directory.Build.props itself
    if grep -q "PackageReference Include=\"UnityMathematics\"" Directory.Build.props 2>/dev/null; then
        warn "Directory.Build.props has PackageReference — should only have version property"
    else
        ok "Directory.Build.props has no direct PackageReference"
    fi
fi

if [ -n "$PKG_NAME" ] && [ -f "package.json" ]; then
    UPM_MATH=$(python3 -c "import json; d=json.load(open('package.json')); print(d.get('dependencies',{}).get('com.unity.mathematics',''))" 2>/dev/null || true)
    if [ -n "$UPM_MATH" ] && [ -n "$MATH_VER" ]; then
        if [ "$UPM_MATH" = "$MATH_VER" ]; then
            ok "NuGet ($MATH_VER) and UPM ($UPM_MATH) mathematics versions aligned"
        else
            fail "Version mismatch: NuGet=$MATH_VER UPM=$UPM_MATH"
        fi
    fi
fi

# ── DLL leak check ──────────────────────────────────────────────

LEAKS=$(find . -path '*/bin' -prune -o -path '*/obj' -prune -o -path './.git' -prune \
    -o -name 'Unity.Mathematics*.dll' -print 2>/dev/null || true)
if [ -z "$LEAKS" ]; then
    ok "No Unity.Mathematics DLL leak"
else
    fail "Unity.Mathematics DLL leaked: $LEAKS"
fi

# ── Placeholder check ──────────────────────────────────────────

if [ "$IS_TEMPLATE" -eq 1 ]; then
    ok "Skipping placeholder check (template repo)"
else
    LEFTOVER=$(grep -rl '__[A-Z_]*__' \
        --include='*.cs' --include='*.json' --include='*.asmdef' \
        . 2>/dev/null | grep -v '/obj/' | grep -v '/bin/' | grep -v '.github/' || true)
    if [ -z "$LEFTOVER" ]; then
        ok "No unreplaced placeholders"
    else
        fail "Unreplaced placeholders: $LEFTOVER"
    fi
fi

# ── Forbidden files ─────────────────────────────────────────────

if [ -f "AGENTS.md" ]; then
    warn "AGENTS.md found — template artifact? Remove if not intentional"
fi
if [ -f "setup.sh" ] || [ -f "install.sh" ]; then
    warn "setup.sh/install.sh found — template artifact? Remove if not intentional"
fi

FORBIDDEN=$(find . -name "*.user" -o -name "*.suo" -o -name ".DS_Store" | grep -v '.git' || true)
if [ -n "$FORBIDDEN" ]; then
    warn "IDE/OS files found: $FORBIDDEN"
fi

# ── Build & test ────────────────────────────────────────────────

echo ""
echo "  ${DIM}── Build & Test ─────────────────────────────────────${RESET}"

SLNX=$(ls *.slnx 2>/dev/null | head -1 || true)
if [ -n "$SLNX" ]; then
    if dotnet restore "$SLNX" >/dev/null 2>&1; then
        ok "dotnet restore"
    else
        fail "dotnet restore failed"
    fi

    if dotnet build "$SLNX" -c Release --no-restore >/dev/null 2>&1; then
        ok "dotnet build (Release)"
    else
        fail "dotnet build failed"
    fi

    if dotnet test "$SLNX" -c Release --no-build --verbosity quiet >/dev/null 2>&1; then
        ok "dotnet test (all pass)"
    else
        fail "dotnet test failed or no tests found"
    fi
else
    warn "No solution file — skipping build/test"
fi

# ── Summary ─────────────────────────────────────────────────────

echo ""
echo "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [ "$FAIL" -eq 0 ]; then
    echo "  ${GREEN}${BOLD}✓ All checks pass${RESET} — $PASS ok, $WARN warnings"
else
    echo "  ${RED}${BOLD}✗ $FAIL failures${RESET}, $PASS ok, $WARN warnings"
fi

echo "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
