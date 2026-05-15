#!/usr/bin/env bash
MSG=$(cat "$1")
PATTERN='^(feat|fix|docs|refactor|test|ci|chore|perf|build|style|revert)(\(.+\))?: .{1,100}$'
if ! echo "$MSG" | grep -qE "$PATTERN"; then
    echo ""
    echo "  BLOCKED: commit message does not follow conventional commits."
    echo "  Required format: type: description"
    echo "  Valid types: feat fix docs refactor test ci chore perf build style revert"
    echo "  Example: fix: remove placeholder from generated package.json"
    echo ""
    echo "  Your message: $MSG"
    exit 1
fi
exit 0
