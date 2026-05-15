# Unity UPM Package Template — Feature Roadmap

> **Rule Zero**: Do not start any phase here until the base TODO is complete (all CI green).
> Each phase stands alone. A weak AI must be able to implement any single phase
> without reading the others first. Every phase ends with a concrete verify block.
> If the verify block does not pass, the phase is not done.

---

## What this file is

The base TODO fixed things that were broken.
This file adds things that do not exist yet.
Each feature is optional but ordered by impact.

---

## Feature priority table

| Phase | Feature | Impact | Effort | Unlocks |
|---|---|---|---|---|
| 13 | Git hooks (pre-commit validation) | 🔥 High | Low | Devs never push broken code |
| 14 | OpenUPM publish pipeline | 🔥 High | Medium | Package discoverable by everyone |
| 15 | API surface diff (breaking change detection) | 🔥 High | Medium | Safe versioning |
| 16 | Auto-generated docs → GitHub Pages | 🔥 High | Medium | Professional package presence |
| 17 | Performance regression CI | Medium | Medium | Confident optimization work |
| 18 | Package upgrade tool | 🔥 High | High | Template stays useful after creation |
| 19 | Multi-LTS Unity version matrix | Medium | Low | Confident compatibility claims |
| 20 | AI changelog generation | Medium | Low | Zero-effort release notes |
| 21 | Local Unity package server | Medium | High | Test before publishing |
| 22 | Monorepo support | Low | High | Large package families |
| 23 | IDE live templates (Rider / VS) | Medium | Low | Faster daily development |
| 24 | Package health badge system | Low | Low | README credibility |
| 25 | Dependency vulnerability scanner | Medium | Low | Supply chain safety |
| 26 | AI test generator (beyond scaffold) | 🔥 High | Medium | Coverage without effort |
| 27 | Sample scene generator | Low | High | Better onboarding |
| 28 | Release checklist workflow | 🔥 High | Low | No forgotten steps |

---

# PHASE 13 — Git hooks (pre-commit validation)

## Why this matters first

Every other quality gate runs in CI. That means broken code is already pushed by the time
the developer finds out. Git hooks run the check before `git commit` completes.
Cost: one second of dev time. Benefit: never push a red build.

## What to build

`scripts/install-hooks.sh` — installs hooks into `.git/hooks/`

```bash
#!/usr/bin/env bash
# Usage: bash scripts/install-hooks.sh
# Installs pre-commit and commit-msg hooks.
set -euo pipefail

HOOKS_DIR="$(git rev-parse --git-dir)/hooks"
SCRIPTS_DIR="$(git rev-parse --show-toplevel)/scripts"
```

### Hook 1: `pre-commit`

Runs fast checks only (under 5 seconds total):

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# 1. No Unity.Mathematics.dll committed
if git diff --cached --name-only | grep -qiE 'Unity\.Mathematics.*\.dll$'; then
    echo "BLOCKED: Unity.Mathematics.dll cannot be committed."
    exit 1
fi

# 2. No placeholder tokens in staged .cs/.json/.asmdef files
STAGED=$(git diff --cached --name-only --diff-filter=ACM \
    | grep -E '\.(cs|json|asmdef)$' || true)
if [ -n "$STAGED" ]; then
    for f in $STAGED; do
        if grep -q '__[A-Z_]\{2,\}__' "$f" 2>/dev/null; then
            echo "BLOCKED: unreplaced placeholder in $f"
            exit 1
        fi
    done
fi

# 3. No bin/obj/artifacts staged
FORBIDDEN=$(git diff --cached --name-only | grep -E '^(bin|obj|artifacts)/' || true)
if [ -n "$FORBIDDEN" ]; then
    echo "BLOCKED: build output staged: $FORBIDDEN"
    exit 1
fi

# 4. Build must pass (skip if no .slnx exists — raw template is ok)
if ls *.slnx >/dev/null 2>&1; then
    dotnet build *.slnx -c Release --nologo -v quiet 2>&1 | tail -3
fi

exit 0
```

### Hook 2: `commit-msg`

Enforces conventional commit format (`type: description`):

```bash
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
```

### Install script body

```bash
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
```

## File layout

```
scripts/
  install-hooks.sh       ← installer (run once after clone)
  hooks/
    pre-commit.sh        ← hook source (tracked in git)
    commit-msg.sh        ← hook source (tracked in git)
```

Store hooks in `scripts/hooks/` (tracked in git) and copy them to `.git/hooks/` (not tracked).
Never put hook logic directly in `.git/hooks/` — it would be invisible to the team.

## Wire into `setup.sh`

At the end of setup.sh, after all cleanup, add:

```bash
# Install git hooks if git is available
if git rev-parse --git-dir >/dev/null 2>&1 && [ -d "scripts/hooks" ]; then
    bash scripts/install-hooks.sh >/dev/null 2>&1 || true
    echo "  ${GREEN}✓${RESET} Git hooks installed"
fi
```

## Wire into README template (in setup.sh)

Add to the `## Dev` section of the generated README:

```markdown
## Dev

\`\`\`bash
dotnet restore
dotnet test -c Release
bash scripts/smoke.sh
\`\`\`

Git hooks are pre-installed. Re-install after cloning: \`bash scripts/install-hooks.sh\`
```

## Verify

```bash
bash scripts/install-hooks.sh

# Test pre-commit blocks a DLL
touch test.dll
git add test.dll
git commit -m "test" && echo "FAIL: should have blocked" || echo "PASS: blocked DLL"
git rm --cached test.dll 2>/dev/null; rm -f test.dll

# Test commit-msg enforces format
git commit --allow-empty -m "bad message" && echo "FAIL" || echo "PASS: bad message blocked"
git commit --allow-empty -m "feat: good message" && echo "PASS: good message allowed" || echo "FAIL"
git reset HEAD~1 --soft  # undo test commit
```

- [ ] `scripts/install-hooks.sh` exists and is executable
- [ ] `scripts/hooks/pre-commit.sh` exists
- [ ] `scripts/hooks/commit-msg.sh` exists
- [ ] pre-commit blocks `.dll` files
- [ ] commit-msg blocks non-conventional messages

Commit: `feat: git hooks for pre-commit validation and commit message format`

---

# PHASE 14 — OpenUPM publish pipeline

## Why this matters

A package that cannot be found by Unity developers does not exist.
OpenUPM is the de facto community registry for Unity packages.
Adding a publish workflow means a developer can run `git tag v1.0.0 && git push --tags`
and the package is live on OpenUPM within minutes — zero manual steps.

## What OpenUPM requires

1. A `package.json` at the repo root with a valid reverse-DNS name
2. A GitHub release with a git tag matching the version
3. A registration PR to `https://github.com/openupm/openupm` (one time, manual)
4. After registration: every new tag triggers OpenUPM's automatic indexer

The template already handles 1 and 2 via `release.yml` and `version.sh`.
This phase adds the missing pieces.

## What to build

### 14.1 — `scripts/publish-openupm.sh`

This script does the one-time registration step:

```bash
#!/usr/bin/env bash
# Usage: bash scripts/publish-openupm.sh
# Generates the OpenUPM registration PR content and opens the browser.
set -euo pipefail

PKG_NAME=$(python3 -c "import json; print(json.load(open('package.json'))['name'])" 2>/dev/null)
PKG_DISPLAY=$(python3 -c "import json; print(json.load(open('package.json'))['displayName'])" 2>/dev/null)
PKG_VER=$(python3 -c "import json; print(json.load(open('package.json'))['version'])" 2>/dev/null)
GH_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//')

if [ -z "$PKG_NAME" ] || [ -z "$GH_URL" ]; then
    echo "Run from a generated package directory with a git remote set."
    exit 1
fi

# Validate not a placeholder
if echo "$PKG_NAME" | grep -q '__'; then
    echo "FAIL: package.json still has placeholders. Run setup.sh first."
    exit 1
fi

# Generate the openupm package entry
ENTRY_FILE="artifacts/openupm-entry.yml"
mkdir -p artifacts
cat > "$ENTRY_FILE" <<YAML
# OpenUPM package entry — submit this file as a PR to:
# https://github.com/openupm/openupm/tree/master/data/packages
# File path: data/packages/${PKG_NAME}.yml

name: $PKG_NAME
displayName: $PKG_DISPLAY
description: $(python3 -c "import json; print(json.load(open('package.json')).get('description',''))" 2>/dev/null)
repoUrl: $GH_URL
parentRepoUrl:
licenseSpdxId: $(python3 -c "import json; print(json.load(open('package.json')).get('license','MIT'))" 2>/dev/null)
licenseName:
topics:
  - unity
  - upm
hunter:
image:
readme: README.md
minScope:
YAML

echo ""
echo "  OpenUPM entry generated: $ENTRY_FILE"
echo ""
echo "  Next steps:"
echo "  1. Review: cat $ENTRY_FILE"
echo "  2. Fork https://github.com/openupm/openupm"
echo "  3. Copy $ENTRY_FILE to data/packages/$PKG_NAME.yml in your fork"
echo "  4. Submit a PR"
echo ""
echo "  After the PR merges, every 'git tag v*' triggers automatic indexing."
echo ""

# Open browser if possible
if command -v open >/dev/null 2>&1; then
    open "https://github.com/openupm/openupm/fork"
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "https://github.com/openupm/openupm/fork"
fi
```

### 14.2 — Add OpenUPM badge to generated README

In `setup.sh`'s README template, add:

```markdown
[![OpenUPM]($OPENUPM_BADGE_URL)](https://openupm.com/packages/$PACKAGE_ID/)
```

Where `OPENUPM_BADGE_URL="https://img.shields.io/npm/v/$PACKAGE_ID?label=openupm&registry_uri=https://package.openupm.com"`.

### 14.3 — Validate `package.json` for OpenUPM requirements in `validate-upm.sh`

Add to validate-upm.sh:

```bash
# OpenUPM requires: description, keywords, author.url or author.email
PKG_DESC=$(python3 -c "import json; print(json.load(open('package.json')).get('description',''))" 2>/dev/null || true)
[ -n "$PKG_DESC" ] && ok "description present (OpenUPM)" || warn "description missing — required for OpenUPM"

PKG_KEYWORDS=$(python3 -c "import json; kw=json.load(open('package.json')).get('keywords',[]); print(len(kw))" 2>/dev/null || echo "0")
[ "$PKG_KEYWORDS" -gt 0 ] && ok "$PKG_KEYWORDS keywords (OpenUPM)" || warn "no keywords — add some for OpenUPM discoverability"
```

### 14.4 — Wire into `release.yml`

Add a step that prints the OpenUPM indexer URL as a reminder:

```yaml
- name: OpenUPM indexer reminder
  run: |
    PKG=$(python3 -c "import json; print(json.load(open('package.json'))['name'])")
    VER=$(python3 -c "import json; print(json.load(open('package.json'))['version'])")
    echo "OpenUPM will index this release automatically if registered."
    echo "Check: https://openupm.com/packages/${PKG}/"
    echo "Register once: bash scripts/publish-openupm.sh"
```

## Verify

```bash
bash scripts/publish-openupm.sh
test -f artifacts/openupm-entry.yml && echo "PASS" || echo "FAIL"
grep -q "repoUrl:" artifacts/openupm-entry.yml && echo "PASS: repoUrl" || echo "FAIL"
grep -q "name:" artifacts/openupm-entry.yml && echo "PASS: name" || echo "FAIL"
```

- [ ] `scripts/publish-openupm.sh` exits 0
- [ ] `artifacts/openupm-entry.yml` exists and contains the package name and repo URL
- [ ] Running on raw template (with placeholders) exits with error

Commit: `feat: OpenUPM publish pipeline and registration helper`

---

# PHASE 15 — API surface diff (breaking change detection)

## Why this matters

A Unity package that introduces a breaking change without bumping the major version silently
breaks every project that depends on it. This is the #1 way packages lose trust.

## What to build

### 15.1 — `scripts/api-surface.sh`

Extracts the public API surface from the Runtime assembly as a plain text manifest:

```bash
#!/usr/bin/env bash
# Usage: bash scripts/api-surface.sh [output-file]
# Produces a sorted list of all public types, methods, properties in the runtime assembly.
set -euo pipefail

OUTPUT="${1:-artifacts/api/surface.txt}"
mkdir -p "$(dirname "$OUTPUT")"

SLNX=$(ls *.slnx 2>/dev/null | head -1)
if [ -z "$SLNX" ]; then
    echo "No .slnx file found." && exit 1
fi

# Build first
dotnet build "$SLNX" -c Release --nologo -v quiet >/dev/null 2>&1

# Find the runtime DLL
DLL=$(find . -path '*/Release/netstandard2.1/*.Runtime.dll' \
    ! -path '*/obj/*' 2>/dev/null | head -1)

if [ -z "$DLL" ]; then
    echo "Runtime DLL not found after build." && exit 1
fi

# Use dotnet-reflect or xmldoc to extract public surface
# Strategy: use the XML doc file (always generated) for public API list
XML="${DLL%.dll}.xml"
if [ -f "$XML" ]; then
    python3 - "$XML" "$OUTPUT" <<'PY'
import sys, xml.etree.ElementTree as ET
tree = ET.parse(sys.argv[1])
members = sorted(m.get("name","") for m in tree.findall(".//member"))
with open(sys.argv[2], "w") as f:
    f.write("\n".join(members) + "\n")
print(f"API surface: {len(members)} members → {sys.argv[2]}")
PY
else
    echo "No XML doc file at $XML — ensure <GenerateDocumentationFile>true</GenerateDocumentationFile>"
    exit 1
fi
```

### 15.2 — `scripts/api-diff.sh`

Compares current surface against a baseline (stored at `artifacts/api/baseline.txt`):

```bash
#!/usr/bin/env bash
# Usage: bash scripts/api-diff.sh
# Compares current API surface against the committed baseline.
# Exits 1 if any public members were REMOVED or RENAMED (breaking change).
set -euo pipefail

BASELINE="artifacts/api/baseline.txt"
CURRENT="artifacts/api/surface.txt"

bash scripts/api-surface.sh "$CURRENT"

if [ ! -f "$BASELINE" ]; then
    echo "  No baseline yet. Creating baseline from current surface."
    cp "$CURRENT" "$BASELINE"
    echo "  Commit artifacts/api/baseline.txt to track future API changes."
    exit 0
fi

REMOVED=$(comm -23 <(sort "$BASELINE") <(sort "$CURRENT"))
ADDED=$(comm -13 <(sort "$BASELINE") <(sort "$CURRENT"))

if [ -n "$REMOVED" ]; then
    echo ""
    echo "  ⚠  BREAKING CHANGE DETECTED"
    echo "  These public members were removed or renamed:"
    echo "$REMOVED" | sed 's/^/    /'
    echo ""
    echo "  If this is intentional: bump the MAJOR version (bash scripts/version.sh major)"
    echo "  Then update the baseline: cp artifacts/api/surface.txt artifacts/api/baseline.txt"
    exit 1
fi

if [ -n "$ADDED" ]; then
    echo "  New public members (non-breaking):"
    echo "$ADDED" | sed 's/^/    /'
fi

echo "  ✓ No breaking changes detected"
exit 0
```

### 15.3 — Add to `smoke.sh`

After the tests step:

```bash
if bash scripts/api-diff.sh 2>/dev/null; then
    step_end "API surface (no breaking changes)"
else
    echo "  ${YELLOW}⚠${RESET} API surface changed — see artifacts/api/"
    # Warning only in smoke.sh; CI makes it a hard failure
fi
```

### 15.4 — Add to `ci.yml`

```yaml
- name: API surface diff
  run: bash scripts/api-diff.sh
```

### 15.5 — `artifacts/api/baseline.txt` committed at `0.1.0`

When `setup.sh` runs, generate an initial baseline immediately:

```bash
# In setup.sh Stage 2, after dotnet build:
if dotnet build "$PACKAGE_ID.slnx" -c Release --nologo -v quiet >/dev/null 2>&1; then
    bash scripts/api-surface.sh artifacts/api/baseline.txt 2>/dev/null || true
    echo "  ${GREEN}✓${RESET} API baseline created"
fi
```

## Verify

```bash
bash scripts/api-surface.sh
test -s artifacts/api/surface.txt && echo "PASS: surface.txt" || echo "FAIL"
bash scripts/api-diff.sh
echo $?  # should be 0 (no diff from itself)
```

- [ ] `scripts/api-surface.sh` exits 0 and produces non-empty output
- [ ] `scripts/api-diff.sh` exits 0 when no API changes exist
- [ ] `scripts/api-diff.sh` exits 1 when a public method is removed
- [ ] `artifacts/api/baseline.txt` is committed

Commit: `feat: API surface diff detects breaking changes before release`

---

# PHASE 16 — Auto-generated docs → GitHub Pages

## Why this matters

A package without docs gets ignored. A package where the docs are always up to date,
generated from the actual source, never stale, published automatically on every release —
that package gets adopted.

## What to build

### 16.1 — `scripts/generate-docs.sh`

Generates Markdown API docs from XML doc comments:

```bash
#!/usr/bin/env bash
# Usage: bash scripts/generate-docs.sh [output-dir]
# Reads XML documentation and generates Markdown API reference.
set -euo pipefail

OUT="${1:-Documentation~/api}"
mkdir -p "$OUT"

SLNX=$(ls *.slnx 2>/dev/null | head -1)
dotnet build "$SLNX" -c Release --nologo -v quiet >/dev/null 2>&1

XML=$(find . -path '*/Release/netstandard2.1/*.xml' ! -path '*/obj/*' 2>/dev/null | head -1)
PKG_NAME=$(python3 -c "import json; print(json.load(open('package.json'))['displayName'])" 2>/dev/null)

if [ -z "$XML" ]; then
    echo "No XML doc file found. Add <GenerateDocumentationFile>true</GenerateDocumentationFile>"
    exit 1
fi

python3 - "$XML" "$OUT" "$PKG_NAME" <<'PY'
import sys, xml.etree.ElementTree as ET, os, re

def strip_tags(text):
    return re.sub(r'<[^>]+>', '', text or '').strip()

def member_kind(name):
    prefix = name[0] if name else '?'
    return {'T': 'Type', 'M': 'Method', 'P': 'Property', 'F': 'Field', 'E': 'Event'}.get(prefix, 'Other')

tree = ET.parse(sys.argv[1])
out_dir = sys.argv[2]
pkg_name = sys.argv[3]

members = {}
for m in tree.findall(".//member"):
    name = m.get("name", "")
    kind = member_kind(name)
    summary = strip_tags(getattr(m.find("summary"), 'text', '') or '')
    returns = strip_tags(getattr(m.find("returns"), 'text', '') or '')
    params = [(p.get("name",""), strip_tags(p.text or '')) for p in m.findall("param")]
    members.setdefault(kind, []).append((name[2:], summary, returns, params))

# Write api.md
with open(os.path.join(out_dir, "api.md"), "w") as f:
    f.write(f"# {pkg_name} API Reference\n\n")
    f.write(f"_Auto-generated from source. Do not edit manually._\n\n")
    for kind in ['Type', 'Method', 'Property', 'Field']:
        items = members.get(kind, [])
        if not items: continue
        f.write(f"## {kind}s\n\n")
        for (name, summary, returns, params) in sorted(items):
            f.write(f"### `{name}`\n\n")
            if summary: f.write(f"{summary}\n\n")
            if params:
                f.write("**Parameters**\n\n")
                for pname, pdesc in params:
                    f.write(f"- `{pname}` — {pdesc}\n")
                f.write("\n")
            if returns: f.write(f"**Returns**: {returns}\n\n")

print(f"Docs written to {out_dir}/api.md")
PY

echo "  ✓ Docs generated at $OUT/api.md"
```

### 16.2 — `.github/workflows/docs.yml`

```yaml
name: docs

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: 9.0.x

      - name: Generate API docs
        run: bash scripts/generate-docs.sh Documentation~/api

      - name: Build docs site
        run: |
          pip install mkdocs mkdocs-material --quiet
          # Create minimal mkdocs.yml if it doesn't exist
          if [ ! -f mkdocs.yml ]; then
            DISPLAY=$(python3 -c "import json; print(json.load(open('package.json'))['displayName'])")
            cat > mkdocs.yml <<YAML
          site_name: $DISPLAY
          docs_dir: Documentation~
          theme:
            name: material
            palette:
              scheme: slate
              primary: deep purple
          YAML
          fi
          mkdocs build --site-dir artifacts/docs

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: artifacts/docs

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

### 16.3 — Add `mkdocs.yml` to `setup.sh` output

Add to setup.sh Stage 2:

```bash
# mkdocs configuration for GitHub Pages
cat > mkdocs.yml <<MKDOCS
site_name: $DISPLAY_NAME
site_description: $DISPLAY_NAME Unity Package
docs_dir: Documentation~
repo_url: https://github.com/$GH_OWNER/$PACKAGE_ID
repo_name: $GH_OWNER/$PACKAGE_ID

theme:
  name: material
  palette:
    scheme: slate
    primary: deep purple
  features:
    - navigation.tabs
    - navigation.instant

nav:
  - Home: index.md
  - Installation: installation.md
  - Quick Start: quick-start.md
  - API Reference: api.md
  - Release Notes: release-notes.md
MKDOCS
echo "  ${GREEN}✓${RESET} mkdocs.yml created"
```

### 16.4 — Add docs badge to generated README

```bash
DOCS_BADGE="https://img.shields.io/badge/docs-pages-blue"
DOCS_URL="https://$GH_OWNER.github.io/$PACKAGE_ID"
# Add to README: [![Docs]($DOCS_BADGE)]($DOCS_URL)
```

## Verify

```bash
bash scripts/generate-docs.sh Documentation~/api
test -f Documentation~/api/api.md && echo "PASS" || echo "FAIL"
grep -q "## " Documentation~/api/api.md && echo "PASS: has sections" || echo "FAIL"
```

- [ ] `scripts/generate-docs.sh` exits 0
- [ ] `Documentation~/api/api.md` is created and non-empty
- [ ] `.github/workflows/docs.yml` exists
- [ ] `mkdocs.yml` is created by `setup.sh`

Commit: `feat: auto-generate API docs and publish to GitHub Pages`

---

# PHASE 17 — Performance regression CI

## Why this matters

BenchmarkDotNet already exists in the template (`Dev~/benchmarks/`).
But benchmarks are never run in CI. That means a performance regression ships silently.

## What to build

### 17.1 — `scripts/bench.sh`

```bash
#!/usr/bin/env bash
# Usage: bash scripts/bench.sh [filter]
# Runs benchmarks and saves results to artifacts/benchmarks/
set -euo pipefail

FILTER="${1:-*}"
SLNX=$(ls *.slnx 2>/dev/null | head -1)

mkdir -p artifacts/benchmarks

dotnet run \
    --project Dev~/benchmarks/*.Benchmarks/*.csproj \
    -c Release \
    -- \
    --filter "$FILTER" \
    --exporters json \
    --artifacts artifacts/benchmarks \
    2>&1 | tee artifacts/benchmarks/run.log

echo "  ✓ Benchmarks complete. Results in artifacts/benchmarks/"
```

### 17.2 — `scripts/bench-compare.sh`

Compares current results against a stored baseline:

```bash
#!/usr/bin/env bash
# Usage: bash scripts/bench-compare.sh
# Fails if any benchmark regressed by more than 10%.
set -euo pipefail

BASELINE="artifacts/benchmarks/baseline.json"
CURRENT=$(find artifacts/benchmarks -name 'BenchmarkDotNet.Artifacts*.json' \
    -newer "$BASELINE" 2>/dev/null | head -1)

if [ -z "$CURRENT" ]; then
    echo "No current benchmark results found. Run scripts/bench.sh first."
    exit 1
fi

if [ ! -f "$BASELINE" ]; then
    echo "No baseline. Creating from current results."
    cp "$CURRENT" "$BASELINE"
    echo "Commit artifacts/benchmarks/baseline.json to track regressions."
    exit 0
fi

python3 - "$BASELINE" "$CURRENT" <<'PY'
import json, sys

def load(path):
    with open(path) as f: return json.load(f)

def bench_map(data):
    out = {}
    for b in data.get("Benchmarks", []):
        name = b.get("FullName") or b.get("Method", "")
        ns = b.get("Statistics", {}).get("Mean", 0)
        out[name] = ns
    return out

baseline = bench_map(load(sys.argv[1]))
current = bench_map(load(sys.argv[2]))

THRESHOLD = 0.10  # 10% regression = failure
failures = []

for name, base_ns in baseline.items():
    cur_ns = current.get(name)
    if cur_ns is None:
        print(f"  ⚠ Benchmark removed: {name}")
        continue
    ratio = (cur_ns - base_ns) / base_ns
    if ratio > THRESHOLD:
        failures.append((name, base_ns, cur_ns, ratio))
        print(f"  ✗ REGRESSION {name}: {base_ns:.0f}ns → {cur_ns:.0f}ns (+{ratio*100:.1f}%)")
    elif ratio < -0.05:
        print(f"  ✓ IMPROVEMENT {name}: {base_ns:.0f}ns → {cur_ns:.0f}ns ({ratio*100:.1f}%)")
    else:
        print(f"  ✓ {name}: {cur_ns:.0f}ns (stable)")

if failures:
    print(f"\n  {len(failures)} performance regressions detected.")
    sys.exit(1)
else:
    print(f"\n  No regressions.")
PY
```

### 17.3 — Add to `release.yml` (not `ci.yml`)

Benchmarks are slow. Run them only before a release, not on every push:

```yaml
- name: Run benchmarks
  run: bash scripts/bench.sh

- name: Check for regressions
  run: bash scripts/bench-compare.sh
```

## Verify

```bash
bash scripts/bench.sh "*"
test -d artifacts/benchmarks && echo "PASS" || echo "FAIL"
bash scripts/bench-compare.sh   # should create baseline on first run
echo $?   # should be 0
```

- [ ] `scripts/bench.sh` exits 0 and produces output
- [ ] `scripts/bench-compare.sh` creates a baseline on first run
- [ ] `scripts/bench-compare.sh` exits 1 when a benchmark is 10%+ slower

Commit: `feat: benchmark CI with regression detection`

---

# PHASE 18 — Package upgrade tool

## Why this matters

Right now, once a developer runs `setup.sh` they are on their own forever.
If a critical bug is fixed in the template (new CI workflow, new script, better .meta handling),
the developer has no way to get the fix without manually diffing two repos.

This is the feature that creates a long-term relationship between the template and its users.

## What to build

### 18.1 — `scripts/upgrade.sh`

```bash
#!/usr/bin/env bash
# Usage: bash scripts/upgrade.sh [--dry-run]
# Upgrades the template infrastructure in a generated package to the latest version.
# Preserves: Runtime/**, Tests/**, Editor/**, package.json, README.md, LICENSE, CHANGELOG.md
# Updates:   scripts/**, .github/workflows/**, Directory.Build.props, global.json
set -euo pipefail

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

TEMPLATE_URL="https://github.com/__AUTHOR__/UnityUPMPackageTemplate.git"
TMP=$(mktemp -d)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# Confirm this is a generated package, not a raw template
if [ -f "__PACKAGE__.Runtime/__PLACEHOLDER__.cs" ]; then
    echo "This is the raw template. Upgrade is for generated packages only."
    exit 1
fi

# Get package identity from package.json
PKG_NAME=$(python3 -c "import json; print(json.load(open('package.json'))['name'])")
PKG_VER=$(python3 -c "import json; print(json.load(open('package.json'))['version'])")

echo ""
echo "  Upgrading $PKG_NAME v$PKG_VER template infrastructure..."
echo ""

# Clone latest template
git clone --depth 1 "$TEMPLATE_URL" "$TMP/template" 2>/dev/null

# Files to upgrade (infrastructure only — never touch source)
UPGRADE_DIRS=(
    ".github/workflows"
    "scripts"
)

UPGRADE_FILES=(
    "Directory.Build.props"
    "global.json"
    ".editorconfig"
    ".gitattributes"
)

# Preserve user values
AUTHOR=$(python3 -c "import json; d=json.load(open('package.json')); print(d.get('author',{}).get('name','') if isinstance(d.get('author'),dict) else d.get('author',''))")
DISPLAY=$(python3 -c "import json; print(json.load(open('package.json'))['displayName'])")
NAMESPACE=$(grep -r 'rootNamespace' --include='*.asmdef' . 2>/dev/null | head -1 | grep -oP '"rootNamespace": "\K[^"]+' || echo "")
UNITY_MIN=$(python3 -c "import json; print(json.load(open('package.json')).get('unity','2022.3'))")
GH_OWNER=$(git remote get-url origin 2>/dev/null | grep -oP 'github\.com[:/]\K[^/]+' || echo "")

CHANGED=0

for dir in "${UPGRADE_DIRS[@]}"; do
    src="$TMP/template/$dir"
    dst="$ROOT/$dir"
    if [ ! -d "$src" ]; then continue; fi
    if $DRY_RUN; then
        echo "  [DRY RUN] Would update: $dir/"
    else
        mkdir -p "$dst"
        # For each file in src, apply token replacement and copy
        find "$src" -type f | while read -r f; do
            rel="${f#$src/}"
            target="$dst/$rel"
            mkdir -p "$(dirname "$target")"
            sed \
                -e "s/__PACKAGE__/$(printf '%s' "$PKG_NAME" | sed 's/[\\/&]/\\&/g')/g" \
                -e "s/__NAMESPACE__/$(printf '%s' "$NAMESPACE" | sed 's/[\\/&]/\\&/g')/g" \
                -e "s/__DISPLAY__/$(printf '%s' "$DISPLAY" | sed 's/[\\/&]/\\&/g')/g" \
                -e "s/__AUTHOR__/$(printf '%s' "$AUTHOR" | sed 's/[\\/&]/\\&/g')/g" \
                -e "s/__UNITY_MIN__/$(printf '%s' "$UNITY_MIN" | sed 's/[\\/&]/\\&/g')/g" \
                "$f" > "$target"
            CHANGED=$((CHANGED + 1))
        done
        echo "  ✓ Updated: $dir/"
    fi
done

for file in "${UPGRADE_FILES[@]}"; do
    src="$TMP/template/$file"
    dst="$ROOT/$file"
    if [ ! -f "$src" ]; then continue; fi
    if $DRY_RUN; then
        echo "  [DRY RUN] Would update: $file"
    else
        # Only overwrite if newer (check content diff)
        if ! diff -q "$src" "$dst" >/dev/null 2>&1; then
            cp "$src" "$dst"
            echo "  ✓ Updated: $file"
            CHANGED=$((CHANGED + 1))
        else
            echo "  ✓ Up to date: $file"
        fi
    fi
done

if $DRY_RUN; then
    echo ""
    echo "  Dry run complete. Run without --dry-run to apply."
else
    echo ""
    echo "  Upgrade complete. Review changes: git diff"
    echo "  Test: bash scripts/smoke.sh"
    echo "  Commit: git add -A && git commit -m 'chore: upgrade template infrastructure'"
fi
echo ""
```

### 18.2 — Add template version tracking

In `setup.sh`, after setup completes, write a `.template-version` file:

```bash
TEMPLATE_SHA=$(git -C "$(dirname "$0")" rev-parse HEAD 2>/dev/null || echo "unknown")
cat > .template-version <<VER
# Auto-generated by setup.sh — do not edit
template_sha: $TEMPLATE_SHA
generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
VER
```

`scripts/upgrade.sh` can compare `.template-version` against the latest template SHA to
tell the developer exactly how far behind they are before upgrading.

## Verify

```bash
# Only valid to run in a generated package (after setup.sh), not raw template
bash scripts/upgrade.sh --dry-run
echo $?  # should be 0
# Should print "Would update: scripts/" etc.
```

- [ ] `scripts/upgrade.sh` exists and is executable
- [ ] `--dry-run` prints what would change without modifying files
- [ ] Running on raw template exits with error message
- [ ] `.template-version` is written by `setup.sh`

Commit: `feat: upgrade.sh syncs template infrastructure to latest version`

---

# PHASE 19 — Multi-LTS Unity version matrix

## Why this matters

Unity has two LTS streams at any time (current + previous). A package author that only tests
against one LTS silently breaks users on the other. The matrix is already started
in `unity-package-test.yml` (2022.3 and 6000.0). This phase formalizes it.

## What to build

### 19.1 — Version matrix as a single source of truth

Create `scripts/unity-versions.sh`:

```bash
#!/usr/bin/env bash
# Central list of Unity versions to test against.
# Source this file: source scripts/unity-versions.sh
# Then use: UNITY_TEST_VERSIONS array

UNITY_TEST_VERSIONS=(
    "2022.3.60f1"   # LTS 2022
    "6000.0.36f1"   # LTS 6 (Unity 6)
)

# Minimum supported version from package.json
UNITY_MIN=$(python3 -c \
    "import json; print(json.load(open('package.json')).get('unity','2022.3'))" \
    2>/dev/null || echo "2022.3")
```

### 19.2 — Update `unity-package-test.yml` to use the matrix correctly

The workflow already has a matrix. Ensure the versions in the workflow match
`unity-versions.sh`. Add a step that reads the minimum version from `package.json`
and warns if the workflow tests a version older than the declared minimum:

```yaml
- name: Validate Unity version compatibility
  run: |
    MIN=$(python3 -c "import json; print(json.load(open('.gameci/package-under-test/package.json')).get('unity','2022.3'))")
    TEST="${{ matrix.unity }}"
    # Compare major.minor
    MIN_MAJOR=$(echo $MIN | cut -d. -f1)
    TEST_MAJOR=$(echo $TEST | cut -d. -f1)
    if [ "$TEST_MAJOR" -lt "$MIN_MAJOR" ]; then
        echo "⚠ Testing Unity $TEST but package requires $MIN+"
    fi
```

### 19.3 — `scripts/generate-compatibility-matrix.sh`

After GameCI runs, reads test results and generates a compatibility table for the README:

```bash
#!/usr/bin/env bash
# Usage: bash scripts/generate-compatibility-matrix.sh
# Outputs a Markdown compatibility table to Documentation~/compatibility.md
set -uo pipefail

# Read test results from artifacts
RESULTS_DIR="${1:-artifacts}"
OUT="Documentation~/compatibility.md"

echo "# Unity Compatibility" > "$OUT"
echo "" >> "$OUT"
echo "| Unity Version | Status | Notes |" >> "$OUT"
echo "|---|---|---|" >> "$OUT"

source scripts/unity-versions.sh 2>/dev/null || true

for ver in "${UNITY_TEST_VERSIONS[@]}"; do
    RESULT_FILE=$(find "$RESULTS_DIR" -name "*.xml" -path "*$ver*" 2>/dev/null | head -1)
    if [ -z "$RESULT_FILE" ]; then
        echo "| $ver | ⏳ Not tested | |" >> "$OUT"
    else
        FAILED=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('$RESULT_FILE')
print(tree.getroot().get('failed','0'))
" 2>/dev/null || echo "?")
        if [ "$FAILED" = "0" ]; then
            echo "| $ver | ✅ Passing | |" >> "$OUT"
        else
            echo "| $ver | ❌ $FAILED failures | |" >> "$OUT"
        fi
    fi
done

echo "" >> "$OUT"
echo "_Last updated: $(date -u +%Y-%m-%d)_" >> "$OUT"

echo "  ✓ Compatibility matrix → $OUT"
```

## Verify

```bash
bash scripts/generate-compatibility-matrix.sh
test -f Documentation~/compatibility.md && echo "PASS" || echo "FAIL"
```

- [ ] `scripts/unity-versions.sh` exists with both LTS versions
- [ ] `scripts/generate-compatibility-matrix.sh` produces `Documentation~/compatibility.md`
- [ ] `unity-package-test.yml` matrix matches versions in `unity-versions.sh`

Commit: `feat: unity version matrix as single source of truth`

---

# PHASE 20 — AI changelog generation

## Why this matters

`scripts/changelog-draft.sh` already exists and categorizes commits.
But it uses basic grep patterns. For complex commits, the categories are wrong.
An AI can read the commit messages and write changelog entries that actually make sense.

## What to build

### 20.1 — `scripts/ai-changelog.sh`

```bash
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
```

### 20.2 — Wire into `version.sh`

Replace the existing CHANGELOG step at the end of `version.sh` with:

```bash
echo ""
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "  ${DIM}Generating AI changelog...${RESET}"
    bash scripts/ai-changelog.sh "$NEW_VERSION" --apply 2>/dev/null || \
        bash scripts/changelog-draft.sh "$NEW_VERSION" --apply 2>/dev/null || true
else
    bash scripts/changelog-draft.sh "$NEW_VERSION" --apply 2>/dev/null || true
fi
```

## Verify

```bash
# Without API key — falls back to changelog-draft.sh
bash scripts/ai-changelog.sh 0.2.0
test -f artifacts/release/CHANGELOG.draft.md && echo "PASS" || echo "FAIL"

# With API key
ANTHROPIC_API_KEY=sk-... bash scripts/ai-changelog.sh 0.2.0
cat artifacts/release/CHANGELOG.draft.md
```

- [ ] Without `ANTHROPIC_API_KEY`, falls back to `changelog-draft.sh`
- [ ] With `ANTHROPIC_API_KEY`, produces human-readable changelog entries
- [ ] `--apply` updates `CHANGELOG.md`

Commit: `feat: AI-powered changelog generation with fallback`

---

# PHASE 23 — IDE live templates (Rider / VS Code)

## Why this matters

The fastest way to write a Unity package type correctly is to type `upm-struct` and press Tab.
Live templates for common patterns (readonly struct, test class, Unity job) save time
and enforce conventions. No other Unity package template ships these.

## What to build

### 23.1 — Rider live templates

Create `Tools~/rider-live-templates.xml`:

```xml
<templateSet group="__DISPLAY__ UPM">
  <template name="upm-struct"
            value="/// &lt;summary&gt;$SUMMARY$&lt;/summary&gt;&#10;public readonly struct $NAME$&#10;{&#10;    $END$&#10;}"
            description="Unity package readonly struct"
            toReformat="true" toShortenFQNames="true">
    <variable name="NAME" expression="" defaultValue="MyStruct" alwaysStopAt="true"/>
    <variable name="SUMMARY" expression="" defaultValue="A readonly struct." alwaysStopAt="true"/>
    <context><option name="CSHARP" value="true"/></context>
  </template>

  <template name="upm-test"
            value="using NUnit.Framework;&#10;&#10;namespace $NAMESPACE$.Tests&#10;{&#10;    public sealed class $NAME$Tests&#10;    {&#10;        [Test]&#10;        public void $NAME$_$SCENARIO$_$EXPECTED$()&#10;        {&#10;            // Arrange&#10;            $END$&#10;            // Act&#10;&#10;            // Assert&#10;        }&#10;    }&#10;}"
            description="NUnit test class"
            toReformat="true" toShortenFQNames="true">
    <variable name="NAMESPACE" expression="" defaultValue="MyNamespace" alwaysStopAt="true"/>
    <variable name="NAME" expression="" defaultValue="MyType" alwaysStopAt="true"/>
    <variable name="SCENARIO" expression="" defaultValue="WhenCondition" alwaysStopAt="true"/>
    <variable name="EXPECTED" expression="" defaultValue="ShouldResult" alwaysStopAt="true"/>
    <context><option name="CSHARP" value="true"/></context>
  </template>

  <template name="upm-bench"
            value="using BenchmarkDotNet.Attributes;&#10;&#10;[MemoryDiagnoser]&#10;public class $NAME$Benchmarks&#10;{&#10;    [Benchmark]&#10;    public $RETURN$ $METHOD$()&#10;    {&#10;        $END$&#10;    }&#10;}"
            description="BenchmarkDotNet benchmark class"
            toReformat="true" toShortenFQNames="true">
    <variable name="NAME" expression="" defaultValue="MyType" alwaysStopAt="true"/>
    <variable name="RETURN" expression="" defaultValue="int" alwaysStopAt="true"/>
    <variable name="METHOD" expression="" defaultValue="Benchmark" alwaysStopAt="true"/>
    <context><option name="CSHARP" value="true"/></context>
  </template>
</templateSet>
```

### 23.2 — VS Code snippets

Create `Tools~/vscode-snippets.code-snippets`:

```json
{
    "UPM Readonly Struct": {
        "prefix": "upm-struct",
        "body": [
            "/// <summary>$2</summary>",
            "public readonly struct $1",
            "{",
            "    $0",
            "}"
        ],
        "description": "Unity package readonly struct"
    },
    "UPM NUnit Test Class": {
        "prefix": "upm-test",
        "body": [
            "using NUnit.Framework;",
            "",
            "namespace ${1:Namespace}.Tests",
            "{",
            "    public sealed class ${2:MyType}Tests",
            "    {",
            "        [Test]",
            "        public void ${2:MyType}_${3:WhenCondition}_${4:ShouldResult}()",
            "        {",
            "            // Arrange",
            "            $0",
            "            // Act",
            "",
            "            // Assert",
            "        }",
            "    }",
            "}"
        ],
        "description": "NUnit test class"
    },
    "UPM Benchmark Class": {
        "prefix": "upm-bench",
        "body": [
            "using BenchmarkDotNet.Attributes;",
            "",
            "[MemoryDiagnoser]",
            "public class ${1:MyType}Benchmarks",
            "{",
            "    [Benchmark]",
            "    public ${2:int} ${3:Benchmark}()",
            "    {",
            "        $0",
            "    }",
            "}",
            ""
        ],
        "description": "BenchmarkDotNet benchmark class"
    }
}
```

### 23.3 — `scripts/install-ide-tools.sh`

```bash
#!/usr/bin/env bash
# Usage: bash scripts/install-ide-tools.sh [--rider] [--vscode]
set -euo pipefail

RIDER=false; VSCODE=false
[ $# -eq 0 ] && RIDER=true && VSCODE=true
for arg in "$@"; do
    case "$arg" in --rider) RIDER=true ;; --vscode) VSCODE=true ;; esac
done

ROOT="$(git rev-parse --show-toplevel)"
TOOLS="$ROOT/Tools~"

if $RIDER; then
    RIDER_TEMPLATES="$HOME/.config/JetBrains/Rider*/templates"
    if ls $RIDER_TEMPLATES >/dev/null 2>&1; then
        cp "$TOOLS/rider-live-templates.xml" $(ls -d $RIDER_TEMPLATES | head -1)/
        echo "  ✓ Rider live templates installed"
    else
        echo "  ⚠ Rider not found. Copy Tools~/rider-live-templates.xml manually."
    fi
fi

if $VSCODE; then
    VSCODE_SNIPPETS="$HOME/.config/Code/User/snippets"
    [ -d "$HOME/Library/Application Support/Code/User/snippets" ] \
        && VSCODE_SNIPPETS="$HOME/Library/Application Support/Code/User/snippets"
    mkdir -p "$VSCODE_SNIPPETS"
    cp "$TOOLS/vscode-snippets.code-snippets" "$VSCODE_SNIPPETS/upm-package.code-snippets"
    echo "  ✓ VS Code snippets installed"
fi
```

## Verify

```bash
test -f Tools~/rider-live-templates.xml && echo "PASS: rider templates" || echo "FAIL"
test -f Tools~/vscode-snippets.code-snippets && echo "PASS: vscode snippets" || echo "FAIL"
bash scripts/install-ide-tools.sh --vscode 2>&1 | grep -q "installed\|not found" && echo "PASS" || echo "FAIL"
```

- [ ] `Tools~/rider-live-templates.xml` exists
- [ ] `Tools~/vscode-snippets.code-snippets` exists
- [ ] `scripts/install-ide-tools.sh` installs to VS Code without errors

Commit: `feat: IDE live templates for Rider and VS Code`

---

# PHASE 24 — Package health badge system

## Why this matters

A README with badges tells a developer in 3 seconds whether the package is maintained,
tested, and safe to depend on. The template already sets up CI and OpenUPM.
This phase adds the badges that communicate trust.

## What badges to add

| Badge | Source | What it shows |
|---|---|---|
| CI status | GitHub Actions | Does it build? |
| Unity version | package.json | What Unity versions are supported |
| License | GitHub | MIT / Apache / etc |
| OpenUPM | OpenUPM registry | Version on OpenUPM |
| Package size | `check-size.sh` output | How big is it |
| Code coverage | Coverlet (add to test project) | % tested |

## What to build

### 24.1 — Code coverage via Coverlet

Add to `Dev~/tests/__PACKAGE__.Tests/__PACKAGE__.Tests.csproj`:

```xml
<ItemGroup>
    <PackageReference Include="coverlet.collector" Version="6.0.2" PrivateAssets="all" />
    <PackageReference Include="coverlet.msbuild" Version="6.0.2" PrivateAssets="all" />
</ItemGroup>
```

Run with coverage in `smoke.sh`:

```bash
dotnet test *.slnx -c Release --no-build \
    --collect:"XPlat Code Coverage" \
    --results-directory artifacts/coverage \
    2>&1 | tee artifacts/coverage/run.log

# Extract percentage
COVERAGE=$(python3 - <<'PY'
import glob, xml.etree.ElementTree as ET, os
files = glob.glob("artifacts/coverage/**/*.xml", recursive=True)
if not files: print("?"); exit()
tree = ET.parse(files[0])
cov = tree.find(".//coverage")
pct = float(cov.get("line-rate","0")) * 100 if cov is not None else 0
print(f"{pct:.0f}")
PY
)
echo "  Coverage: $COVERAGE%"
```

### 24.2 — Generate a shields.io badge URL for package size

In `check-size.sh`, after the size calculation, write a badge URL:

```bash
COLOR="brightgreen"
[ "$TOTAL_KB" -gt 200 ] && COLOR="yellow"
[ "$TOTAL_KB" -gt "$MAX_KB" ] && COLOR="red"

mkdir -p artifacts/badges
echo "https://img.shields.io/badge/size-${TOTAL_KB}KB-${COLOR}" > artifacts/badges/size.txt
```

### 24.3 — Update README template in `setup.sh`

The BADGE_URL line already exists. Expand to:

```bash
BADGE_CI="https://github.com/$GH_OWNER/$PACKAGE_ID/actions/workflows/ci.yml/badge.svg"
BADGE_OPENUPM="https://img.shields.io/npm/v/$PACKAGE_ID?label=openupm&registry_uri=https://package.openupm.com"
BADGE_LICENSE="https://img.shields.io/github/license/$GH_OWNER/$PACKAGE_ID"
BADGE_UNITY="https://img.shields.io/badge/Unity-$UNITY_MIN%2B-black?logo=unity"

# In the README heredoc:
# [![CI]($BADGE_CI)](https://github.com/$GH_OWNER/$PACKAGE_ID/actions)
# [![License]($BADGE_LICENSE)](LICENSE)
# [![Unity]($BADGE_UNITY)](https://unity.com)
# [![OpenUPM]($BADGE_OPENUPM)](https://openupm.com/packages/$PACKAGE_ID/)
```

## Verify

```bash
grep -c "img.shields.io" README.md   # should be > 1 after setup.sh runs
# after running setup.sh in test dir:
cd /tmp/test-pkg
grep "img.shields.io" README.md | wc -l
# expected: 3 or more
```

- [ ] Generated README has at least 3 badges
- [ ] `check-size.sh` writes `artifacts/badges/size.txt`
- [ ] Coverlet package reference added to test csproj

Commit: `feat: README badges for CI, license, Unity version, OpenUPM`

---

# PHASE 25 — Dependency vulnerability scanner

## Why this matters

A Unity package that pulls in a NuGet with a known CVE is a supply chain liability.
This is a one-script check that catches the obvious risks.

## What to build

### 25.1 — `scripts/audit-deps.sh`

```bash
#!/usr/bin/env bash
# Usage: bash scripts/audit-deps.sh
# Checks all NuGet packages in the solution for known vulnerabilities.
set -euo pipefail

SLNX=$(ls *.slnx 2>/dev/null | head -1)
if [ -z "$SLNX" ]; then echo "No solution file." && exit 1; fi

echo ""
echo "  Auditing NuGet dependencies..."
echo ""

# dotnet list package --vulnerable requires .NET 7+
dotnet restore "$SLNX" --nologo -v quiet >/dev/null 2>&1

RESULT=$(dotnet list "$SLNX" package --vulnerable --include-transitive 2>&1)
echo "$RESULT"

if echo "$RESULT" | grep -q "has the following vulnerable packages"; then
    echo ""
    echo "  ✗ Vulnerable packages found. Update or replace them before releasing."
    exit 1
fi

echo ""
echo "  ✓ No known vulnerabilities in NuGet packages"

# Also check package.json dependencies (UPM — no automated vuln db, just age check)
echo ""
echo "  Unity package dependencies:"
python3 - <<'PY'
import json, urllib.request, datetime

with open("package.json") as f:
    pkg = json.load(f)

deps = pkg.get("dependencies", {})
for name, ver in deps.items():
    print(f"  {name}: {ver}")

if not deps:
    print("  (none)")
PY
```

### 25.2 — Add to `ci.yml`

```yaml
- name: Audit dependencies
  run: bash scripts/audit-deps.sh
  continue-on-error: true  # warn, don't fail CI — vulns in transitive deps are often unavoidable
```

### 25.3 — Add to `release.yml` as a hard failure

```yaml
- name: Audit dependencies (release gate)
  run: bash scripts/audit-deps.sh
  # No continue-on-error here — do not release with known vulns
```

## Verify

```bash
bash scripts/audit-deps.sh
echo $?   # should be 0 for a clean package
```

- [ ] `scripts/audit-deps.sh` exits 0 on a clean package
- [ ] `scripts/audit-deps.sh` exits 1 if a vulnerable package is detected
- [ ] Added to `ci.yml` as `continue-on-error: true`
- [ ] Added to `release.yml` as a hard gate

Commit: `feat: NuGet vulnerability audit in CI and release pipeline`

---

# PHASE 28 — Release checklist workflow

## Why this matters

Every release is a chance to forget something. The current `release.yml` runs validation
but has no human-readable pre-release checklist. A developer who is about to tag `v1.0.0`
should see a printed list of every step they are about to execute.

## What to build

### 28.1 — `scripts/pre-release.sh`

```bash
#!/usr/bin/env bash
# Usage: bash scripts/pre-release.sh <version>
# Runs the full pre-release checklist. Must all pass before tagging.
set -uo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: bash scripts/pre-release.sh <version>"
    exit 1
fi

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' RESET=$'\033[0m'
PASS=0; FAIL=0; WARN=0

ok()   { ((PASS++)); echo "  ${GREEN}✓${RESET} $1"; }
fail() { ((FAIL++)); echo "  ${RED}✗${RESET} $1"; }
warn() { ((WARN++)); echo "  ${YELLOW}⚠${RESET} $1"; }

cd "$(git rev-parse --show-toplevel)"

echo ""
echo "  ${BOLD}Pre-release checklist for v$VERSION${RESET}"
echo ""

# 1. package.json version matches
PKG_VER=$(python3 -c "import json; print(json.load(open('package.json'))['version'])")
[ "$PKG_VER" = "$VERSION" ] \
    && ok "package.json version: $PKG_VER" \
    || fail "package.json version ($PKG_VER) ≠ $VERSION — run: bash scripts/version.sh $VERSION"

# 2. Tag does not already exist
git tag | grep -q "^v$VERSION$" \
    && fail "Tag v$VERSION already exists" \
    || ok "Tag v$VERSION not yet created"

# 3. Working tree is clean
[ -z "$(git status --porcelain)" ] \
    && ok "Working tree clean" \
    || fail "Uncommitted changes — commit or stash before releasing"

# 4. On main branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$BRANCH" = "main" ] \
    && ok "On main branch" \
    || warn "On branch $BRANCH (expected main)"

# 5. Build passes
dotnet build *.slnx -c Release --nologo -v quiet >/dev/null 2>&1 \
    && ok "Build passes" \
    || fail "Build failed"

# 6. Tests pass
dotnet test *.slnx -c Release --no-build --verbosity quiet >/dev/null 2>&1 \
    && ok "Tests pass" \
    || fail "Tests failed"

# 7. No breaking API changes (if baseline exists)
if [ -f artifacts/api/baseline.txt ]; then
    bash scripts/api-diff.sh >/dev/null 2>&1 \
        && ok "No breaking API changes" \
        || fail "Breaking API change detected — bump major version or update baseline"
else
    warn "No API baseline — run: bash scripts/api-surface.sh artifacts/api/baseline.txt"
fi

# 8. CHANGELOG.md has an entry for this version
grep -q "\[$VERSION\]" CHANGELOG.md 2>/dev/null \
    && ok "CHANGELOG.md has entry for $VERSION" \
    || fail "CHANGELOG.md missing entry for $VERSION — run: bash scripts/ai-changelog.sh $VERSION --apply"

# 9. No known vulnerabilities
bash scripts/audit-deps.sh >/dev/null 2>&1 \
    && ok "No vulnerable dependencies" \
    || warn "Vulnerable dependencies found — review before releasing"

# 10. Package size within budget
bash scripts/check-size.sh 500 >/dev/null 2>&1 \
    && ok "Package size within budget" \
    || fail "Package too large — review and remove unnecessary files"

# 11. UPM structure valid
bash scripts/validate-upm.sh >/dev/null 2>&1 \
    && ok "UPM structure valid" \
    || fail "UPM structure invalid"

echo ""
echo "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [ "$FAIL" -eq 0 ]; then
    echo "  ${GREEN}${BOLD}✓ All checks pass. Safe to release.${RESET}"
    echo ""
    echo "  Run:"
    echo "    git tag v$VERSION"
    echo "    git push origin main --tags"
else
    echo "  ${RED}${BOLD}✗ $FAIL checks failed. Do not release.${RESET}"
fi

echo "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

### 28.2 — Add to `README` template in `setup.sh`

```markdown
## Release

\`\`\`bash
bash scripts/version.sh 0.2.0           # bump version + changelog
bash scripts/pre-release.sh 0.2.0       # verify everything is ready
git tag v0.2.0 && git push --tags       # trigger release CI
\`\`\`
```

### 28.3 — Replace the manual release instructions in all docs

Anywhere the docs say "bump version and tag", replace with the three-command flow above.

## Verify

```bash
bash scripts/pre-release.sh 0.1.0
# Expected: most checks pass, CHANGELOG check may fail if no entry
# Run scripts/version.sh 0.1.0 first to ensure all conditions can be met
```

- [ ] `scripts/pre-release.sh` exists and is executable
- [ ] Exits 0 only when ALL non-warn checks pass
- [ ] Exits 1 and lists failures when any check fails
- [ ] Generated README contains the 3-command release flow

Commit: `feat: pre-release checklist prevents broken releases`

---

# Feature summary

| Phase | Script/File added | Removes a pain point |
|---|---|---|
| 13 | `scripts/install-hooks.sh`, `scripts/hooks/` | Never push broken code again |
| 14 | `scripts/publish-openupm.sh` | Package discoverable by the Unity community |
| 15 | `scripts/api-surface.sh`, `scripts/api-diff.sh` | Breaking changes caught before users feel them |
| 16 | `scripts/generate-docs.sh`, `docs.yml`, `mkdocs.yml` | Docs always up to date, zero maintenance |
| 17 | `scripts/bench.sh`, `scripts/bench-compare.sh` | Performance regressions caught before release |
| 18 | `scripts/upgrade.sh`, `.template-version` | Template stays useful for the life of the package |
| 19 | `scripts/unity-versions.sh`, `generate-compatibility-matrix.sh` | Compatibility claims are accurate |
| 20 | `scripts/ai-changelog.sh` | Release notes take 10 seconds |
| 23 | `Tools~/rider-live-templates.xml`, `Tools~/vscode-snippets.code-snippets` | Correct code patterns at your fingertips |
| 24 | README badges, Coverlet integration | README communicates trust in 3 seconds |
| 25 | `scripts/audit-deps.sh` | No silent supply chain risks |
| 28 | `scripts/pre-release.sh` | Every release is complete, nothing forgotten |

---

# Definition of done for this file

A feature phase is done when:

1. All scripts it describes exist and are executable
2. All verify commands at the bottom of the phase pass
3. The commit described was made and CI is still green after it
4. The generated README (from `setup.sh`) mentions the feature where appropriate

No feature phase is "done" just because the code was written.
The verify block must pass. That is the only definition of done.
