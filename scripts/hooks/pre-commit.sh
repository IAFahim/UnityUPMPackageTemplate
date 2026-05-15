#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# 1. No Unity.Mathematics.dll committed
if git diff --cached --name-only | grep -qiE 'Unity\.Mathematics.*\.dll$'; then
    echo "BLOCKED: Unity.Mathematics.dll cannot be committed."
    exit 1
fi

# 2. No placeholder tokens in staged .cs/.json/.asmdef files (ignore template placeholder files)
STAGED=$(git diff --cached --name-only --diff-filter=ACM \
    | grep -E '\.(cs|json|asmdef)$' | grep -v '__PACKAGE__' | grep -v '__PLACEHOLDER__' || true)
if [ -n "$STAGED" ]; then
    for f in $STAGED; do
        if grep -q '__[A-Z_]\{2,\}__' "$f" 2>/dev/null; then
            echo "BLOCKED: unreplaced placeholder in $f"
            exit 1
        fi
    done
fi

# 3. No bin/obj/artifacts staged
FORBIDDEN=$(git diff --cached --name-only | grep -E '^(bin|obj|artifacts)/' | grep -v 'artifacts/api/baseline.txt' || true)
if [ -n "$FORBIDDEN" ]; then
    echo "BLOCKED: build output staged: $FORBIDDEN"
    exit 1
fi

# 4. Build must pass (skip if no .slnx exists — raw template is ok)
if ls *.slnx >/dev/null 2>&1; then
    dotnet build *.slnx -c Release --nologo -v quiet 2>&1 | tail -3
fi

exit 0
