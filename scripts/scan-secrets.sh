#!/usr/bin/env bash
# ── Scan for accidentally committed secrets ─────────────────────
set -uo pipefail

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' RESET=$'\033[0m'

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

echo ""
echo "  ${BOLD}Scanning for secrets...${RESET}"
echo ""

FOUND=0

# Common secret patterns
PATTERNS=(
    # API keys
    'api[_-]?key\s*[:=]\s*["\x27]?[A-Za-z0-9_-]{20,}'
    # Passwords
    'password\s*[:=]\s*["\x27]?[^\s]{8,}'
    # Tokens
    '(github|gitlab|bearer)[_-]?token\s*[:=]\s*["\x27]?[A-Za-z0-9_-]{20,}'
    # AWS
    'AKIA[0-9A-Z]{16}'
    'aws[_-]?secret[_-]?access[_-]?key\s*[:=]'
    # Private keys
    '-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----'
    # Unity serials
    'UNITY_SERIAL\s*[:=]\s*["\x27]?[A-Z0-9-]{20,}'
    # Connection strings
    'mongodb(\+srv)?://[^\s]+'
    'postgres(ql)?://[^\s]+'
    'mysql://[^\s]+'
)

# Check staged and tracked files
FILES=$(git ls-files | grep -vE '\.(lock|map|meta|asset|prefab|unity|png|jpg|dll|ico)$' | head -500)

for pattern in "${PATTERNS[@]}"; do
    MATCHES=$(echo "$FILES" | xargs grep -l -P "$pattern" 2>/dev/null || true)
    if [ -n "$MATCHES" ]; then
        for m in $MATCHES; do
            echo "  ${RED}✗${RESET} $m — matches pattern: $pattern"
            ((FOUND++)) || true
        done
    fi
done

# Check for .env files
ENV_FILES=$(git ls-files | grep -E '\.env($|\.local|\.production|\.staging)' || true)
if [ -n "$ENV_FILES" ]; then
    for f in $ENV_FILES; do
        echo "  ${RED}✗${RESET} $f — .env file committed"
        ((FOUND++)) || true
    done
fi

# Check for common secret files
SECRET_FILES=$(git ls-files | grep -iE '(id_rsa|id_ed25519|\.pem|\.p12|\.pfx|\.key|\.keystore|\.jks)' || true)
if [ -n "$SECRET_FILES" ]; then
    for f in $SECRET_FILES; do
        echo "  ${RED}✗${RESET} $f — secret key file committed"
        ((FOUND++)) || true
    done
fi

# Try gitleaks if available
if command -v gitleaks >/dev/null 2>&1; then
    echo "  ${DIM}Running gitleaks...${RESET}"
    if ! gitleaks detect --no-banner 2>/dev/null; then
        echo "  ${RED}✗${RESET} gitleaks found issues"
        ((FOUND++)) || true
    fi
fi

echo ""
if [ "$FOUND" -eq 0 ]; then
    echo "  ${GREEN}${BOLD}✓ No secrets detected${RESET}"
    exit 0
else
    echo "  ${RED}${BOLD}✗ $FOUND potential secret(s) found${RESET}"
    echo ""
    echo "  Remediation:"
    echo "    1. Remove the file or redact the value"
    echo "    2. If already pushed: rotate the secret immediately"
    echo "    3. Use git-filter-branch or BFG to purge from history"
    echo "    4. Add to .gitignore"
    exit 1
fi
