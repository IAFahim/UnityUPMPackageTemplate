#!/usr/bin/env bash
# Usage: ANTHROPIC_API_KEY=sk-... bash scripts/ai-changelog.sh [--since v0.1.0] [--apply]
# Generates an AI-written changelog section from git history.
set -euo pipefail

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "Set ANTHROPIC_API_KEY to use AI changelog. Falling back to scripts/changelog-draft.sh"
    bash scripts/changelog-draft.sh "${1:-}" "${2:-}"
    exit $?
fi

SINCE=""
APPLY=false
VERSION=""

for arg in "$@"; do
    case "$arg" in
        --since) SINCE_NEXT=true ;;
        --apply) APPLY=true ;;
        v*) [ "${SINCE_NEXT:-false}" = "true" ] && SINCE="$arg" && SINCE_NEXT=false || VERSION="${arg#v}" ;;
        [0-9]*) VERSION="$arg" ;;
    esac
done

[ -z "$VERSION" ] && VERSION=$(python3 -c "import json; print(json.load(open('package.json'))['version'])" 2>/dev/null)

LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
RANGE="${SINCE:-${LAST_TAG:+$LAST_TAG..HEAD}}"
RANGE="${RANGE:-HEAD}"

COMMITS=$(git log --oneline $RANGE 2>/dev/null | head -50)

if [ -z "$COMMITS" ]; then
    echo "No commits found since ${LAST_TAG:-beginning}."
    exit 0
fi

PROMPT="You are writing a changelog for a Unity C# package.
Version: $VERSION
Date: $(date +%Y-%m-%d)

Here are the git commits since the last release:
$COMMITS

Write a changelog section in Keep a Changelog format.
Rules:
- Group under Added, Changed, Fixed, Removed (only include non-empty groups)
- Each entry is one sentence, past tense, user-facing benefit (not implementation detail)
- Skip merge commits, formatting commits, and CI-only changes
- Be specific. 'Fixed crash when GridCoord2 was used with Burst' not 'Fixed bugs'
- Output ONLY the markdown, starting with ## [$VERSION] - $(date +%Y-%m-%d)
- No preamble, no explanation"

RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
    -H "Content-Type: application/json" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "{
        \"model\": \"claude-sonnet-4-20250514\",
        \"max_tokens\": 1000,
        \"messages\": [{\"role\": \"user\", \"content\": $(echo "$PROMPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}]
    }" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['content'][0]['text'])")

echo ""
echo "$RESPONSE"
echo ""

mkdir -p artifacts/release
echo "$RESPONSE" > artifacts/release/CHANGELOG.draft.md

if $APPLY && [ -f "CHANGELOG.md" ]; then
    {
        head -5 CHANGELOG.md
        echo ""
        echo "$RESPONSE"
        echo ""
        tail -n +6 CHANGELOG.md
    } > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
    echo "  ✓ CHANGELOG.md updated"
else
    echo "  Draft saved to artifacts/release/CHANGELOG.draft.md"
    echo "  Apply with: --apply"
fi
