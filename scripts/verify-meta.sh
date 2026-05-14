#!/usr/bin/env bash
# ── Verify .meta file integrity for Unity assets ────────────────
set -uo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' RESET=$'\033[0m'
PASS=0 FAIL=0 WARN=0

ok()   { ((PASS++)); echo "  ${GREEN}✓${RESET} $1"; }
fail() { ((FAIL++)); echo "  ${RED}✗${RESET} $1"; }
warn() { ((WARN++)); echo "  ${YELLOW}⚠${RESET} $1"; }

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

echo ""
echo "  ${BOLD}Checking .meta file integrity...${RESET}"
echo ""

# Asset types that require .meta files in Unity
META_EXTENSIONS="cs asmdef unity prefab asset mat png jpg jpeg uxml uss ttf oga wav mp3"

# ── Check 1: Every asset has a matching .meta ──────────────────

for ext in $META_EXTENSIONS; do
    while IFS= read -r f; do
        # Skip bin/obj
        [[ "$f" == */bin/* || "$f" == */obj/* ]] && continue
        meta="${f}.meta"
        if [ ! -f "$meta" ]; then
            warn "Missing .meta: $f"
        fi
    done < <(find . -name "*.$ext" -not -path './.git/*' 2>/dev/null)
done

META_COUNT=$(find . -name "*.meta" -not -path './.git/*' -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | wc -l)
ok "Found $META_COUNT .meta files"

# ── Check 2: No orphan .meta files (no matching asset) ─────────

ORPHANS=0
while IFS= read -r meta; do
    [[ "$meta" == */bin/* || "$meta" == */obj/* ]] && continue
    asset="${meta%.meta}"
    if [ ! -f "$asset" ] && [ ! -d "$asset" ]; then
        fail "Orphan .meta: $meta"
        ((ORPHANS++))
    fi
done < <(find . -name "*.meta" -not -path './.git/*' 2>/dev/null)

[ "$ORPHANS" -eq 0 ] && ok "No orphan .meta files"

# ── Check 3: No duplicate GUIDs ────────────────────────────────

DUPES=$(find . -name "*.meta" -not -path './.git/*' -not -path '*/bin/*' -not -path '*/obj/*' \
    -exec grep -h 'guid:' {} \; 2>/dev/null \
    | sed 's/.*guid: *//' | sort | uniq -d)

if [ -z "$DUPES" ]; then
    ok "No duplicate GUIDs"
else
    for guid in $DUPES; do
        fail "Duplicate GUID $guid in:"
        grep -rl "guid: $guid" --include="*.meta" . 2>/dev/null | sed 's/^/    /'
    done
fi

# ── Check 4: No empty GUIDs ────────────────────────────────────

EMPTY=$(find . -name "*.meta" -not -path './.git/*' -not -path '*/bin/*' -not -path '*/obj/*' \
    -exec grep -l 'guid: *$' {} \; 2>/dev/null || true)

[ -z "$EMPTY" ] && ok "No empty GUIDs" || fail "Empty GUIDs: $EMPTY"

# ── Check 5: GUIDs are lowercase hex ────────────────────────────

BAD_GUID=$(find . -name "*.meta" -not -path './.git/*' -not -path '*/bin/*' -not -path '*/obj/*' \
    -exec grep -h 'guid:' {} \; 2>/dev/null \
    | sed 's/.*guid: *//' | grep -vE '^[0-9a-f]{32}$' | head -5 || true)

[ -z "$BAD_GUID" ] && ok "All GUIDs are valid lowercase hex" || fail "Bad GUIDs: $BAD_GUID"

# ── Summary ─────────────────────────────────────────────────────

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  ${GREEN}${BOLD}✓ Meta files OK${RESET} — $PASS ok, $WARN warnings"
else
    echo "  ${RED}${BOLD}✗ $FAIL meta issues${RESET} — $PASS ok, $WARN warnings"
fi
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
