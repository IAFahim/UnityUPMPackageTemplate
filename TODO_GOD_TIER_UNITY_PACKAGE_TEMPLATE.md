# TODO.md — GOD-Tier Unity UPM Package Factory

Goal: turn this repository into a one-command Unity package generator that creates, validates, tests, documents, releases, and debugs Unity packages with minimal user input.

Primary promise:

```text
User presses Enter a few times
↓
Repository becomes a professional Unity UPM package
↓
dotnet tests pass
↓
Unity/GameCI tests pass
↓
Samples and metadata are validated
↓
AI context is generated
↓
Release artifacts are produced
↓
GitHub release contains .unitypackage, .tgz, .zip, compact logs, and AI-ready source dump
```

Non-negotiable rule:

```text
Never pretend secrets can be magically invented.
Automate secret creation only when the user provides values locally or via a privileged token.
Never print secrets.
Never commit secrets.
Never store Unity licenses in repo files.
```

---

## Phase 0 — Define the target UX

### 0.1 Add CLI modes

Create a polished CLI entrypoint:

```text
unity-package create
unity-package doctor
unity-package secrets
unity-package release
unity-package validate
unity-package ai-context
unity-package compact
unity-package version
unity-package self-test
```

Implementation choices:

- Option A: keep Bash scripts first.
- Option B: create a .NET global/local tool later.
- Option C: ship both.

Minimum first version:

```text
install.sh
setup.sh
scripts/doctor.sh
scripts/setup-secrets.sh
scripts/validate-upm.sh
scripts/verify-meta.sh
scripts/export-unitypackage.sh
scripts/generate-ai-context.sh
scripts/compact-ci-results.sh
scripts/version.sh
scripts/test-template.sh
```

Acceptance:

- `./setup.sh --yes` works without prompts when defaults are valid.
- `./setup.sh` works interactively.
- `./scripts/doctor.sh` explains missing tools without crashing.
- All scripts are idempotent where possible.

---

## Phase 1 — Smart defaults and “press Enter” setup

### 1.1 Improve identity detection

Update `setup.sh` and `install.sh`.

Auto-detect:

```text
Folder name
GitHub username/org from `gh api user -q .login`
Git author from `git config --global user.name`
Git email from `git config --global user.email`
Package ID from folder name or GitHub owner
Display name from package ID
Namespace from package ID
Unity version from installed Unity Hub folders
Current year
License
Repository visibility
```

Default mapping:

```text
folder:           my-cool-package
github owner:     VexInteractive
package id:       com.vexinteractive.my-cool-package
display name:     My Cool Package
namespace:        VexInteractive.MyCoolPackage
unity fallback:   2022.3
license:          MIT
```

Acceptance:

- Empty Enter flow creates a valid package.
- `--yes` creates a valid package without prompts.
- Invalid package IDs fail with a helpful message.
- Values containing `/`, `&`, spaces, quotes, or apostrophes do not break replacement.

### 1.2 Add proper escaping

Add safe replacement helpers.

Bash helper:

```bash
escape_sed_replacement() {
    printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}
```

Use escaped values for:

```text
PACKAGE_ID
DISPLAY_NAME
DESCRIPTION
AUTHOR
NAMESPACE
YEAR
GH_OWNER
UNITY_VERSION
```

Acceptance:

- Author `Vex & Co/Interactive` does not break setup.
- Display name `Cool Package: Math/AI` does not break setup.
- Namespace with dots remains valid.

---

## Phase 2 — GitHub secret automation

### 2.1 Add local secret setup script

Create:

```text
scripts/setup-secrets.sh
```

Purpose:

- Use GitHub CLI to create repository secrets.
- Ask only for values that are missing.
- Never echo sensitive values.
- Allow file-based secret input for Unity `.ulf`.

Required secrets:

```text
UNITY_EMAIL
UNITY_PASSWORD
UNITY_LICENSE
```

Optional secrets:

```text
UNITY_SERIAL
SERVICESTACK_LICENSE
SERVICESTACK_CERTIFICATE
OPENAI_API_KEY
ANTHROPIC_API_KEY
GEMINI_API_KEY
GC_PAT
RELEASE_PAT
```

Command examples:

```bash
./scripts/setup-secrets.sh
./scripts/setup-secrets.sh --repo owner/repo
./scripts/setup-secrets.sh --unity-personal
./scripts/setup-secrets.sh --unity-pro
./scripts/setup-secrets.sh --servicestack
./scripts/setup-secrets.sh --ai
```

Implementation sketch:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-}"
if [ -z "$REPO" ]; then
    REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
fi

require_gh() {
    command -v gh >/dev/null 2>&1 || {
        echo "gh CLI is required. Install GitHub CLI or use manual secret setup."
        exit 1
    }
    gh auth status >/dev/null
}

secret_exists() {
    gh secret list --repo "$REPO" | awk '{print $1}' | grep -qx "$1"
}

set_secret_prompt() {
    local name="$1"
    if secret_exists "$name"; then
        echo "✓ $name already exists"
        return
    fi

    echo "Enter value for $name. Input is hidden:"
    gh secret set "$name" --repo "$REPO"
}

set_secret_file() {
    local name="$1"
    local path="$2"

    if [ ! -f "$path" ]; then
        echo "Missing file: $path"
        exit 1
    fi

    gh secret set "$name" --repo "$REPO" < "$path"
}
```

Acceptance:

- If `gh` is missing, the script prints manual fallback instructions.
- If user is not logged in, the script tells them to run `gh auth login`.
- Existing secrets are not overwritten unless `--force` is passed.
- Secret values are never printed.
- `UNITY_LICENSE` can be loaded from a `.ulf` file.

### 2.2 Add manual fallback docs

Create:

```text
.github/UNITY_CI_SETUP.md
```

Include:

```text
How to create Unity license file
How to add GitHub secrets manually
How to run unity-activation workflow
How to test secrets with a workflow dispatch
How to remove/rotate secrets
```

Acceptance:

- A new user can set up GameCI without prior knowledge.
- The docs explicitly say secrets are never committed.

### 2.3 Add GitHub secret audit script

Create:

```text
scripts/check-secrets.sh
```

Purpose:

- Check which expected secrets exist.
- Do not read values.
- Print missing secrets.

Output example:

```text
Secrets check for owner/repo

✓ UNITY_EMAIL
✓ UNITY_PASSWORD
✗ UNITY_LICENSE missing
- SERVICESTACK_LICENSE optional
- OPENAI_API_KEY optional
```

Acceptance:

- Works without exposing secret values.
- Exits 0 if required secrets exist.
- Exits 1 if required secrets are missing.

---

## Phase 3 — Tool installation automation

### 3.1 Add optional local tool installer

Create:

```text
scripts/install-dev-tools.sh
```

Ask:

```text
Install local developer helpers?
- GitHub CLI check
- .NET tool manifest
- Test log compactors
- GC AI context CLI
- Optional okai via npx only
```

Rules:

- Do not globally install by default.
- Prefer local `.config/dotnet-tools.json`.
- Prefer `npx` for Node tools.
- Always support GitHub Actions running everything without local installs.

Acceptance:

- Local developer can opt in.
- CI does not require preinstalled user tools.
- Tools can be restored with one command.

### 3.2 Add dotnet tool manifest

Create:

```bash
dotnet new tool-manifest
```

Install local tools when published/available:

```bash
dotnet tool install Com.BovineLabs.TestResultsCompact
dotnet tool install Com.BovineLabs.TestLogCompact
```

If not published yet, use project references under `tools/`.

Acceptance:

- `dotnet tool restore` works.
- CI can run compactors from source before tools are published.

---

## Phase 4 — GameCI Unity test automation

### 4.1 Add GameCI package test workflow

Create:

```text
.github/workflows/unity-package-test.yml
```

Requirements:

- Use Linux runner.
- Pass explicit Unity version.
- Use package mode.
- Do not test package from repository root.
- Copy package to a subfolder first.

Workflow skeleton:

```yaml
name: unity-package-test

on:
  push:
    branches: [ main ]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read
  checks: write

jobs:
  unity-test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        unity:
          - 2022.3.60f1

    steps:
      - uses: actions/checkout@v4

      - name: Prepare package under test
        run: |
          mkdir -p .gameci/package-under-test
          rsync -a \
            --exclude='.git' \
            --exclude='.github' \
            --exclude='bin' \
            --exclude='obj' \
            --exclude='artifacts' \
            --exclude='.gameci' \
            ./ .gameci/package-under-test/

      - name: Run Unity package tests
        id: unity-tests
        uses: game-ci/unity-test-runner@v4
        env:
          UNITY_LICENSE: ${{ secrets.UNITY_LICENSE }}
          UNITY_EMAIL: ${{ secrets.UNITY_EMAIL }}
          UNITY_PASSWORD: ${{ secrets.UNITY_PASSWORD }}
        with:
          packageMode: true
          projectPath: .gameci/package-under-test
          unityVersion: ${{ matrix.unity }}
          testMode: All
          githubToken: ${{ secrets.GITHUB_TOKEN }}

      - name: Upload Unity test artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: unity-test-results-${{ matrix.unity }}
          path: ${{ steps.unity-tests.outputs.artifactsPath }}
```

Acceptance:

- Workflow runs on PR and main.
- Failed Unity tests appear in GitHub Checks.
- Artifacts are uploaded even on failure.
- No Unity package root hang.

### 4.2 Add Unity activation workflow

Create:

```text
.github/workflows/unity-activation.yml
```

Purpose:

- Request a Unity activation file.
- Upload `.alf` artifact.
- User converts it to `.ulf`.
- User stores `.ulf` as `UNITY_LICENSE`.

Workflow skeleton:

```yaml
name: unity-activation

on:
  workflow_dispatch:

jobs:
  activation:
    runs-on: ubuntu-latest
    steps:
      - name: Request Unity activation file
        id: activation
        uses: game-ci/unity-request-activation-file@v2

      - name: Upload activation file
        uses: actions/upload-artifact@v4
        with:
          name: unity-activation-file
          path: ${{ steps.activation.outputs.filePath }}
```

Acceptance:

- User can run workflow manually.
- Artifact is available for download.
- Docs explain next steps.

---

## Phase 5 — dotnet CI hardening

### 5.1 Make tests fail hard

Update existing `.github/workflows/ci.yml`.

Ensure:

```text
dotnet restore
dotnet build
dotnet test
DLL leak scan
placeholder scan
UPM manifest validation
meta validation
```

Acceptance:

- Failed tests fail CI.
- Failed placeholder scan fails CI.
- Failed DLL leak scan fails CI.
- Failed UPM validation fails CI.

### 5.2 Add package quality gate

Create:

```text
scripts/validate-upm.sh
```

Check:

```text
package.json exists
package.json has name
package.json has version
package.json has displayName
package.json has description
package.json has unity
package.json has license
package.json has author
Runtime asmdef exists
Tests asmdef exists
asmdef names match package ID
package dependencies match asmdef references
README exists
LICENSE exists
CHANGELOG exists or intentionally omitted
Documentation~ exists if docs enabled
Samples exists if samples enabled
No Unity.Mathematics*.dll outside bin/obj
No Library/
No Temp/
No Logs/
No UserSettings/
No obj/
No bin/
No unreplaced placeholders
```

Acceptance:

- Script exits 0 on a clean generated package.
- Script exits 1 and prints exact file/problem on failure.

---

## Phase 6 — Metadata and GUID validation

### 6.1 Add meta validation script

Create:

```text
scripts/verify-meta.sh
```

Check:

```text
Every Unity asset has a .meta
Every .meta has a matching asset or folder
No duplicate GUIDs
No missing GUIDs
No malformed GUIDs
No Library/Temp metadata committed
No orphaned .meta files
```

Unity asset extensions to check:

```text
.cs
.asmdef
.json
.unity
.prefab
.asset
.mat
.controller
.anim
uxml
uss
png
jpg
jpeg
svg
shader
compute
```

Script skeleton:

```bash
#!/usr/bin/env bash
set -euo pipefail

fail=0

is_unity_asset() {
    case "$1" in
        *.cs|*.asmdef|*.json|*.unity|*.prefab|*.asset|*.mat|*.controller|*.anim|*.uxml|*.uss|*.png|*.jpg|*.jpeg|*.svg|*.shader|*.compute)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

while IFS= read -r asset; do
    case "$asset" in
        */bin/*|*/obj/*|*/Library/*|*/Temp/*|*/Logs/*|*/UserSettings/*) continue ;;
    esac

    if is_unity_asset "$asset" && [ ! -f "$asset.meta" ]; then
        echo "Missing meta: $asset.meta"
        fail=1
    fi
done < <(find . -type f ! -name '*.meta')

while IFS= read -r meta; do
    asset="${meta%.meta}"
    if [ ! -e "$asset" ]; then
        echo "Orphan meta: $meta"
        fail=1
    fi
done < <(find . -type f -name '*.meta')

dupes=$(grep -rh '^guid:' . --include='*.meta' | awk '{print $2}' | sort | uniq -d || true)
if [ -n "$dupes" ]; then
    echo "Duplicate GUIDs:"
    echo "$dupes"
    fail=1
fi

exit "$fail"
```

Acceptance:

- Missing `.meta` fails.
- Orphan `.meta` fails.
- Duplicate GUID fails.
- Clean generated package passes.

### 6.2 Add Unity meta repair command

Create:

```text
scripts/repair-meta-with-unity.sh
```

Purpose:

- Create temp Unity project.
- Copy package into `Assets/PackageUnderRepair`.
- Let Unity import and generate missing meta.
- Copy generated meta back.
- Run `verify-meta.sh`.

Acceptance:

- Does not overwrite existing `.meta` unless `--force`.
- Prints a list of generated metadata files.
- Requires Unity installed locally or runs in CI.

---

## Phase 7 — Samples, dummy scene, and UI Toolkit demo

### 7.1 Add sample generation option

Installer prompt:

```text
Create samples?
[1] None
[2] QuickStart scene
[3] QuickStart + UI Toolkit demo
```

Default:

```text
QuickStart + UI Toolkit demo
```

Create:

```text
Samples/
  QuickStart/
    QuickStart.unity
    QuickStartController.cs
    README.md
  UIToolkitDemo/
    Editor/
      PackageDoctorWindow.cs
      PackageDoctorWindow.uxml
      PackageDoctorWindow.uss
    README.md
```

Acceptance:

- Samples are listed in `package.json`.
- Unity Package Manager can import samples.
- Sample scene has valid `.meta`.
- Sample scripts compile.

### 7.2 Update package.json samples

Add:

```json
"samples": [
  {
    "displayName": "Quick Start",
    "description": "Minimal scene showing the package working.",
    "path": "Samples/QuickStart"
  },
  {
    "displayName": "UI Toolkit Demo",
    "description": "Editor UI demo for package tooling.",
    "path": "Samples/UIToolkitDemo"
  }
]
```

Acceptance:

- `scripts/validate-upm.sh` confirms sample paths exist.
- Unity import smoke test confirms samples import.

---

## Phase 8 — Package Doctor Editor UI

### 8.1 Add optional Editor assembly

Create:

```text
__PACKAGE__.Editor/
  __PACKAGE__.Editor.asmdef
  PackageDoctorWindow.cs
  PackageDoctorWindow.uxml
  PackageDoctorWindow.uss
```

Menu item:

```text
Tools/<Display Name>/Package Doctor
```

Checks:

```text
package.json valid
asmdef names valid
dependencies synced
samples configured
docs exist
meta files valid
no duplicate GUIDs
no DLL leaks
Unity.Mathematics reference resolved
tests found
release artifacts found
```

Buttons:

```text
Run EditMode Tests
Run PlayMode Tests
Export .unitypackage
Open Documentation
Validate Metadata
Copy AI Context Prompt
```

Acceptance:

- Editor assembly is excluded from runtime.
- Package Doctor opens in Unity.
- Window does not require external packages unless declared.

---

## Phase 9 — Test result compactor integration

### 9.1 Vendor or reference compactors

Create one of:

```text
tools/TestResultsCompact/
tools/TestLogCompact/
```

or install from:

```text
com.bovinelabs.compactors
```

Capabilities required:

```text
TestResultsCompact:
- input TestResults.xml
- output compact text
- stdout option
- exit 1 if tests failed

TestLogCompact:
- input Editor.log/TestLog.log
- output compact text
- stdout option
- exit 1 if compile errors exist
```

Acceptance:

- Failing Unity test produces readable compact summary.
- Unity compile error produces readable compact summary.
- CI uploads full and compact logs.

### 9.2 Add compact CI script

Create:

```text
scripts/compact-ci-results.sh
```

Inputs:

```text
artifacts/**/*.xml
artifacts/**/*.log
```

Outputs:

```text
artifacts/compact/TestResults.compact.txt
artifacts/compact/EditorLog.compact.txt
artifacts/compact/summary.md
```

Append to GitHub summary:

```bash
cat artifacts/compact/summary.md >> "$GITHUB_STEP_SUMMARY"
```

Acceptance:

- Always runs on CI failure.
- Always uploads artifacts.
- Summary is short enough to read in GitHub UI.

---

## Phase 10 — AI context generation using GC

### 10.1 Add AI context script

Create:

```text
scripts/generate-ai-context.sh
```

Behavior:

```text
Generate full codebase markdown
Generate compressed markdown
Generate release-debug prompt
Generate failing-test prompt if compact logs exist
```

Command examples:

```bash
./scripts/generate-ai-context.sh
./scripts/generate-ai-context.sh --compress
./scripts/generate-ai-context.sh --brain
./scripts/generate-ai-context.sh --release
```

Outputs:

```text
artifacts/ai/codebase.md
artifacts/ai/codebase.compact.md
artifacts/ai/release-debug-prompt.md
artifacts/ai/test-failure-prompt.md
```

Implementation:

```bash
#!/usr/bin/env bash
set -euo pipefail

mkdir -p artifacts/ai

if command -v gc >/dev/null 2>&1; then
    GC="gc"
else
    GC="npx -y @iafahim/gc"
fi

$GC --output artifacts/ai/codebase.md
$GC --brain --compress --output artifacts/ai/codebase.compact.md || true
```

If the real package name for GC differs, update this command after checking the repository.

Acceptance:

- CI generates AI context without local install.
- Local users can run it.
- Release attaches both full and compact AI context.
- Generated context excludes `Library`, `Temp`, `bin`, `obj`, `.git`, release artifacts, and secrets.

### 10.2 Add AI context workflow

Create:

```text
.github/workflows/ai-context.yml
```

Triggers:

```text
push
pull_request
workflow_dispatch
```

Artifacts:

```text
ai-context-full
ai-context-compact
release-debug-pack
```

Acceptance:

- Every PR has an AI context artifact.
- Every release has an AI context artifact.
- Artifacts do not include secrets.

---

## Phase 11 — LLM-assisted docs

### 11.1 Add optional docs generation command

Create:

```text
scripts/generate-docs-ai.sh
```

Purpose:

- Use a small/free LLM through `npx okai chat` or another provider.
- Generate README summary, package description, changelog draft, and docs pages.
- Never auto-commit AI output without review unless `--yes` is passed.

Modes:

```bash
./scripts/generate-docs-ai.sh
./scripts/generate-docs-ai.sh --provider okai
./scripts/generate-docs-ai.sh --provider openai
./scripts/generate-docs-ai.sh --provider none
```

Inputs:

```text
package.json
Runtime/**/*.cs
README.md
CHANGELOG.md
Documentation~/**/*.md
artifacts/ai/codebase.compact.md
```

Outputs:

```text
artifacts/ai-docs/README.draft.md
artifacts/ai-docs/DESCRIPTION.draft.txt
artifacts/ai-docs/CHANGELOG.draft.md
artifacts/ai-docs/Documentation.index.draft.md
```

Acceptance:

- Works without API keys when okai is available.
- Does not fail main CI if the free AI service rate-limits.
- Never overwrites README unless `--apply`.
- Adds clear marker:

```text
Generated draft. Review before release.
```

### 11.2 Add personalized package wording

Installer asks:

```text
Package personality?
[1] Professional
[2] Fun
[3] Minimal
[4] Performance-focused
[5] Enterprise
```

Use it to generate:

```text
README tone
Description
Docs intro
Terminal success message
Release notes style
```

Acceptance:

- Professional mode is default.
- Generated package still looks serious.
- Fun mode is tasteful, not noisy.

---

## Phase 12 — Release automation

### 12.1 Add release workflow

Create:

```text
.github/workflows/release.yml
```

Trigger:

```text
push tag v*
workflow_dispatch
```

Jobs:

```text
validate
dotnet-test
unity-test
export-unitypackage
pack-upm
ai-context
compact-results
github-release
```

Artifacts:

```text
dist/<package-id>-<version>.unitypackage
dist/<package-id>-<version>.tgz
dist/<package-id>-<version>.zip
dist/<package-id>-<version>-ai-context.md
dist/<package-id>-<version>-ai-context.compact.md
dist/<package-id>-<version>-test-summary.md
```

Acceptance:

- Tag `v0.1.0` fails if `package.json` version is not `0.1.0`.
- Release is not created if tests fail.
- Failed release uploads compact diagnostics.

### 12.2 Export `.unitypackage`

Create:

```text
tools/UnityPackageExporter/Assets/Editor/ReleaseExporter.cs
scripts/export-unitypackage.sh
```

Exporter behavior:

```text
Create temporary Unity project
Copy package contents into Assets/<DisplayName>
Import assets
Generate missing meta if needed
Export package
Write artifact path
```

Acceptance:

- `.unitypackage` is created.
- It imports into a clean Unity project.
- Imported project compiles.
- Sample scene opens without missing scripts.

### 12.3 Pack UPM `.tgz`

Create:

```text
scripts/pack-upm.sh
```

Use npm package packing if package format is compatible:

```bash
npm pack --pack-destination dist
```

Acceptance:

- `.tgz` is created.
- It does not include `.git`, `.github`, `bin`, `obj`, `artifacts`, `Library`, `Temp`.
- It includes Runtime, Tests, Samples, Documentation, package.json, README, LICENSE.

---

## Phase 13 — Clean-project install smoke tests

### 13.1 Test UPM Git install

Create workflow job:

```text
install-smoke-upm
```

Steps:

```text
Create empty Unity project
Add package by local path or git URL
Open Unity batchmode
Compile
Run EditMode tests
```

Acceptance:

- Package installs through UPM.
- Unity resolves dependencies.
- Runtime assembly compiles.

### 13.2 Test `.unitypackage` import

Create workflow job:

```text
install-smoke-unitypackage
```

Steps:

```text
Create empty Unity project
Import generated .unitypackage
Open Unity batchmode
Compile
Run smoke scene
```

Acceptance:

- `.unitypackage` imports cleanly.
- No missing script references.
- No duplicate GUID errors.
- No compile errors.

---

## Phase 14 — Versioning and changelog

### 14.1 Add version script

Create:

```text
scripts/version.sh
```

Usage:

```bash
./scripts/version.sh 0.2.0
./scripts/version.sh 0.2.0-alpha.1
./scripts/version.sh patch
./scripts/version.sh minor
./scripts/version.sh major
```

Updates:

```text
package.json version
CHANGELOG.md
README badge/snippet if needed
git tag optional
```

Acceptance:

- Invalid semver fails.
- Tag and package version match.
- Changelog gets a new section.

### 14.2 Add changelog generation

Create:

```text
scripts/changelog-draft.sh
```

Inputs:

```text
git commits since last tag
merged PR titles
package.json version
```

Outputs:

```text
artifacts/release/CHANGELOG.draft.md
```

Acceptance:

- Does not overwrite CHANGELOG unless `--apply`.
- Groups Added/Changed/Fixed/Removed.

---

## Phase 15 — Agent support

### 15.1 Generate agent instruction files

Create:

```text
AGENTS.md
CLAUDE.md
.github/copilot-instructions.md
.cursor/rules/unity-package.mdc
Skills~/
  unity-package/SKILL.md
  gameci/SKILL.md
  meta-files/SKILL.md
  release-debugging/SKILL.md
  docs/SKILL.md
```

Each must say:

```text
Source lives in Runtime/
Do not edit bin/obj/Library/Temp
Do not commit Unity.Mathematics DLL
Keep package.json and asmdefs synced
Run scripts/smoke.sh before final answer
Run scripts/verify-meta.sh after asset changes
Use compact logs before debugging CI failures
```

Acceptance:

- Agent instructions remain after setup.
- No template placeholders remain.
- Instructions mention exact scripts to run.

### 15.2 Add AI failure bundle

When CI fails, upload:

```text
failure-debug-pack.zip
  compact logs
  full logs
  package.json
  asmdefs
  generated AI context compact file
  environment summary
```

Acceptance:

- User can download one zip and give it to an AI.
- The zip excludes secrets.

---

## Phase 16 — Package Doctor CLI

### 16.1 Add `doctor.sh`

Create:

```text
scripts/doctor.sh
```

Checks:

```text
OS
bash version
git installed
gh installed and logged in
dotnet SDK installed
Node/npm installed
Unity installed
Unity Hub path detected
package.json valid
solution exists
dotnet restore works
dotnet build works
dotnet test works
meta valid
UPM valid
secrets exist
GameCI workflows exist
release workflow exists
```

Output:

```text
✓ dotnet SDK 9.0.x
✓ package.json valid
✗ UNITY_LICENSE missing
! Unity not installed locally; CI can still run with GameCI
```

Acceptance:

- Gives exact fix commands.
- Does not require every optional tool.
- Exits nonzero only for required failures.

---

## Phase 17 — Dependency sync checker

### 17.1 Add asmdef/package dependency checker

Create:

```text
tools/DependencySyncChecker/
```

Check:

```text
package.json dependencies
Runtime asmdef references
Tests asmdef references
Editor asmdef references
Directory.Build.props NuGet versions
csproj PackageReferences
```

Special rule:

```text
com.unity.mathematics package version and UnityMathematics NuGet version must be intentionally mapped.
```

Acceptance:

- Missing asmdef reference fails.
- Missing package.json dependency fails.
- Version drift warns or fails depending on config.

---

## Phase 18 — Security and permissions

### 18.1 Harden workflow permissions

Every workflow must define minimal permissions.

Examples:

```yaml
permissions:
  contents: read
```

Release workflow:

```yaml
permissions:
  contents: write
  checks: write
```

PR workflows:

```yaml
permissions:
  contents: read
  checks: write
```

Acceptance:

- No workflow uses broad permissions unless needed.
- Release job has write permission only where needed.

### 18.2 Add secret scanning guidance

Add:

```text
scripts/scan-secrets.sh
```

Use available tools if installed:

```text
gitleaks
trufflehog
GitHub secret scanning docs link in SECURITY.md
```

Acceptance:

- Local scan can run.
- CI scan can run optionally.
- False positives are documented.

---

## Phase 19 — Docs and README quality

### 19.1 Generate Documentation~

Create:

```text
Documentation~/
  index.md
  installation.md
  quick-start.md
  samples.md
  testing.md
  release.md
  troubleshooting.md
```

Acceptance:

- Docs exist after setup.
- README links to docs.
- No broken relative links.

### 19.2 Add README badges

Generate badges:

```text
dotnet CI
Unity package tests
Release
License MIT
Unity version
UPM Git
```

Acceptance:

- Badges point to the correct owner/repo.
- Private repo mode can disable public badges.

---

## Phase 20 — Template self-test

### 20.1 Add self-test script

Create:

```text
scripts/test-template.sh
```

Steps:

```text
Create temp directory
Run installer with --yes
Create package com.test.generated
Run dotnet restore/build/test
Run validate-upm
Run verify-meta
Run no-placeholder scan
Run no-DLL-leak scan
Optionally run Unity/GameCI local test
Optionally export .unitypackage
```

Acceptance:

- Template tests itself before release.
- This script runs in CI.

### 20.2 Add self-test workflow

Create:

```text
.github/workflows/template-self-test.yml
```

Triggers:

```text
push
pull_request
workflow_dispatch
```

Acceptance:

- PR fails if template generation breaks.
- Artifacts include generated package debug logs.

---

## Phase 21 — Release polish

### 21.1 Final success screen

After setup, print:

```text
Package ready.

Generated:
✓ Runtime assembly
✓ Test assembly
✓ dotnet CI
✓ Unity GameCI workflow
✓ Unity activation helper
✓ Release workflow
✓ .unitypackage exporter
✓ AI context workflow
✓ Test log compactors
✓ Metadata validator
✓ Package Doctor
✓ Agent Skills

Next:
1. Push to GitHub
2. Run ./scripts/setup-secrets.sh
3. Run GitHub Actions → unity-activation if using Unity Personal
4. Push tag v0.1.0 to create a release
```

Acceptance:

- The final screen tells users exactly what to do next.
- No vague “figure it out” steps.

---

## Phase 22 — Stretch features

Do these after core works.

### 22.1 Installer personality themes

Modes:

```text
professional
fun
minimal
enterprise
performance
```

Affects:

```text
README style
terminal messages
docs intro
package description
sample text
```

### 22.2 ServiceStack/okai docs assistant

Optional command:

```bash
./scripts/generate-docs-ai.sh --provider okai
```

Rules:

```text
Use only for drafts
Never fail required CI due to AI provider outage
Never auto-publish unreviewed AI docs unless --yes
```

### 22.3 Package quality score

Generate:

```text
artifacts/package-score.md
```

Score:

```text
CI: 20
Unity tests: 20
Meta valid: 15
Docs: 10
Samples: 10
Release artifacts: 15
AI context: 5
Security: 5
```

### 22.4 Local TUI

Create a friendly terminal UI:

```text
[✓] Identity
[✓] Runtime
[✓] Tests
[✓] GameCI
[✓] Secrets
[✓] Release
[✓] AI Context
```

### 22.5 GitHub issue bot prompt pack

Create files:

```text
.github/ISSUE_TEMPLATE/bug_report.yml
.github/ISSUE_TEMPLATE/ci_failure.yml
.github/ISSUE_TEMPLATE/feature_request.yml
```

CI failure template asks for:

```text
compact logs
Unity version
package version
install method
```

---

## Final implementation order

Do not implement everything randomly. Use this order:

```text
1. Harden setup/install scripts
2. Add validate-upm.sh
3. Add verify-meta.sh
4. Add doctor.sh
5. Add setup-secrets.sh
6. Add GameCI Unity package test workflow
7. Add unity activation workflow
8. Add compactors
9. Add AI context generation
10. Add release workflow
11. Add .unitypackage exporter
12. Add .unitypackage import smoke test
13. Add samples and dummy scene
14. Add Documentation~
15. Add Agent Skills~
16. Add Package Doctor UI
17. Add template self-test workflow
18. Add docs AI draft generator
19. Add version/changelog automation
20. Add polish/personality themes
```

---

## Definition of done

The project is GOD-tier only when this command sequence works:

```bash
bash <(curl -sL INSTALL_URL/install.sh) my-package --yes
cd my-package
./scripts/doctor.sh
./scripts/smoke.sh
./scripts/validate-upm.sh
./scripts/verify-meta.sh
./scripts/generate-ai-context.sh
git push -u origin main
git tag v0.1.0
git push origin v0.1.0
```

And GitHub Actions produces:

```text
✓ dotnet CI passed
✓ Unity GameCI tests passed
✓ Metadata validation passed
✓ UPM validation passed
✓ .unitypackage exported
✓ .unitypackage import smoke test passed
✓ UPM tgz created
✓ AI context generated
✓ Compact logs generated
✓ GitHub release created
```

Release assets must include:

```text
<package-id>-<version>.unitypackage
<package-id>-<version>.tgz
<package-id>-<version>.zip
<package-id>-<version>-ai-context.md
<package-id>-<version>-ai-context.compact.md
<package-id>-<version>-test-summary.md
```

If any step fails, the failure must produce:

```text
compact readable summary
full logs
AI debug context
exact next action
```

That is the target.
