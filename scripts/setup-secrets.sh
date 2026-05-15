#!/usr/bin/env bash
# ── Setup GitHub secrets for GameCI ─────────────────────────────
# Usage:
#   ./scripts/setup-secrets.sh
#   ./scripts/setup-secrets.sh --repo owner/repo
#   ./scripts/setup-secrets.sh --unity-personal
#   ./scripts/setup-secrets.sh --unity-pro
#   ./scripts/setup-secrets.sh --force
set -euo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' RESET=$'\033[0m'

FORCE=false
REPO=""
MODE=""

for arg in "$@"; do
    case "$arg" in
        --repo=*)   REPO="${arg#--repo=}" ;;
        --repo)     shift; REPO="$1" ;;
        --force)    FORCE=true ;;
        --unity-personal) MODE="personal" ;;
        --unity-pro)      MODE="pro" ;;
        *)          echo "Unknown arg: $arg"; exit 1 ;;
    esac
done

echo ""
echo "  ${BOLD}GitHub Secret Setup${RESET}"
echo ""

# ── Require gh ──────────────────────────────────────────────────

if ! command -v gh >/dev/null 2>&1; then
    echo "  ${RED}✗${RESET} gh CLI required. Install: https://cli.github.com"
    echo "  Fallback: GitHub → Settings → Secrets → New secret"
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "  ${RED}✗${RESET} Not logged in. Run: gh auth login"
    exit 1
fi

# Detect repo
if [ -z "$REPO" ]; then
    REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
fi

if [ -z "$REPO" ]; then
    echo "  ${RED}✗${RESET} Cannot detect repo. Use --repo owner/repo"
    exit 1
fi

echo "  Repository: ${BOLD}$REPO${RESET}"
echo ""

# ── Helpers ─────────────────────────────────────────────────────

secret_exists() {
    gh secret list --repo "$REPO" 2>/dev/null | awk '{print $1}' | grep -qx "$1"
}

set_secret_prompt() {
    local name="$1"
    local desc="$2"

    if secret_exists "$name" && [ "$FORCE" != "true" ]; then
        echo "  ${GREEN}✓${RESET} $name already set"
        return 0
    fi

    echo ""
    echo "  ${BOLD}$name${RESET} — $desc"
    echo "  Enter value (input hidden). Press Ctrl+C to skip."
    if gh secret set "$name" --repo "$REPO" 2>/dev/null; then
        echo "  ${GREEN}✓${RESET} $name set"
    else
        echo "  ${RED}✗${RESET} Failed to set $name"
    fi
}

set_secret_from_file() {
    local name="$1"
    local path="$2"

    if [ ! -f "$path" ]; then
        echo "  ${RED}✗${RESET} File not found: $path"
        return 1
    fi

    gh secret set "$name" --repo "$REPO" < "$path" 2>/dev/null
    echo "  ${GREEN}✓${RESET} $name set from $path"
}

# ── Required secrets ────────────────────────────────────────────

echo "  ${BOLD}── Unity Secrets ──${RESET}"

if [ "$MODE" = "pro" ] || [ "$MODE" = "" ]; then
    set_secret_prompt "UNITY_EMAIL"    "Unity account email"
    set_secret_prompt "UNITY_PASSWORD" "Unity account password"
fi

if [ "$MODE" = "personal" ] || [ "$MODE" = "" ]; then
    # Check for .ulf file
    ULF_FILE=$(find . -maxdepth 1 -name "*.ulf" -o -name "*.xml" 2>/dev/null | head -1)
    if [ -n "$ULF_FILE" ]; then
        echo "  Found license file: $ULF_FILE"
        read -rp "  Use this for UNITY_LICENSE? [Y/n] " USE_FILE
        if [[ ! "$USE_FILE" =~ ^[Nn] ]]; then
            set_secret_from_file "UNITY_LICENSE" "$ULF_FILE"
        else
            set_secret_prompt "UNITY_LICENSE" "Unity license file content (.ulf/.xml)"
        fi
    else
        echo ""
        echo "  ${DIM}To get UNITY_LICENSE:${RESET}"
        echo "  ${DIM}1. Run Actions → unity-activation on your repo${RESET}"
        echo "  ${DIM}2. Download the .alf file${RESET}"
        echo "  ${DIM}3. Convert at https://license.unity3d.com/manual${RESET}"
        echo "  ${DIM}4. Save the .ulf file${RESET}"
        echo "  ${DIM}5. Re-run: $0 --repo $REPO${RESET}"
        echo ""
        set_secret_prompt "UNITY_LICENSE" "Unity license file content (.ulf/.xml)"
    fi
fi

if [ "$MODE" = "pro" ]; then
    set_secret_prompt "UNITY_SERIAL" "Unity Pro serial number"
fi

# ── Summary ─────────────────────────────────────────────────────

echo ""
echo "  ${BOLD}Secrets status:${RESET}"
echo ""

for s in UNITY_EMAIL UNITY_PASSWORD UNITY_LICENSE; do
    if secret_exists "$s"; then
        echo "  ${GREEN}✓${RESET} $s"
    else
        echo "  ${YELLOW}⊘${RESET} $s (not set)"
    fi
done

echo ""
echo "  Done. GameCI workflows will use these secrets."
echo ""
