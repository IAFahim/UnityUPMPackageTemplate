#!/usr/bin/env bash
# Usage: bash scripts/install-hooks.sh
# Installs pre-commit and commit-msg hooks.
set -euo pipefail

HOOKS_DIR="$(git rev-parse --git-dir)/hooks"
SCRIPTS_DIR="$(git rev-parse --show-toplevel)/scripts"

# Write pre-commit hook
cat "$SCRIPTS_DIR/hooks/pre-commit.sh" > "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"
echo "  ✓ pre-commit hook installed"

# Write commit-msg hook
cat "$SCRIPTS_DIR/hooks/commit-msg.sh" > "$HOOKS_DIR/commit-msg"
chmod +x "$HOOKS_DIR/commit-msg"
echo "  ✓ commit-msg hook installed"

echo ""
echo "  Git hooks active. Run 'bash scripts/install-hooks.sh' after cloning."
