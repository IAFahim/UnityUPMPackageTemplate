#!/usr/bin/env bash
# ── Check which GitHub secrets exist (without reading values) ───
set -uo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' RESET=$'\033[0m'

REPO="${1:-}"
if [ -z "$REPO" ]; then
    REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
fi

if [ -z "$REPO" ]; then
    echo "Usage: $0 owner/repo"
    exit 1
fi

echo ""
echo "  ${BOLD}Secrets check for $REPO${RESET}"
echo ""

REQUIRED=("UNITY_EMAIL" "UNITY_PASSWORD" "UNITY_LICENSE")
OPTIONAL=("UNITY_SERIAL")

EXIT=0

for s in "${REQUIRED[@]}"; do
    if gh secret list --repo "$REPO" 2>/dev/null | awk '{print $1}' | grep -qx "$s"; then
        echo "  ${GREEN}✓${RESET} $s"
    else
        echo "  ${RED}✗${RESET} $s missing"
        EXIT=1
    fi
done

for s in "${OPTIONAL[@]}"; do
    if gh secret list --repo "$REPO" 2>/dev/null | awk '{print $1}' | grep -qx "$s"; then
        echo "  ${GREEN}✓${RESET} $s"
    else
        echo "  ${DIM}-${RESET} $s optional"
    fi
done

echo ""
[ "$EXIT" -eq 0 ] && echo "  ${GREEN}${BOLD}✓ All required secrets set${RESET}" || echo "  ${RED}${BOLD}✗ Missing required secrets${RESET}"
echo ""

exit $EXIT
