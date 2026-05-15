# 🛠️ System Bug Fix TODO

This document outlines critical issues in the Unity UPM Package Template repository. Follow these instructions exactly, step-by-step, to resolve the bugs. After making the changes, run the test commands at the bottom to verify.

## 🚨 Phase 1: Critical CI & Script Crashes

- [ ] **Fix 1: Impossible CI Condition in `stage-unity-package-test.sh`**
  - **File:** `scripts/stage-unity-package-test.sh`
  - **Issue:** On line 15, the script calls `setup.sh` using literal placeholder strings (`__PACKAGE__`, `__NAMESPACE__`). Because of this, the check on line 31 that ensures placeholders are removed *always* fails.
  - **Action:** Change line 15 to pass real values instead of placeholders.
    - **Change from:**
      `bash setup.sh __PACKAGE__ "Unity Package Self Test" "__AUTHOR__" "__NAMESPACE__"`
    - **Change to:**
      `bash setup.sh com.gameci.selftest "Unity Package Self Test" "GameCI" "GameCI.SelfTest"`

- [ ] **Fix 2: Unbound Variable Crash in `generate-compatibility-matrix.sh`**
  - **File:** `scripts/generate-compatibility-matrix.sh`
  - **Issue:** The script runs with `set -uo pipefail` (which crashes on unbound variables). On line 13, it loops over `${UNITY_TEST_VERSIONS[@]}`. If `scripts/unity-versions.sh` fails to source or doesn't exist, the script hard-crashes.
  - **Action:** Initialize the array *before* sourcing the external file.
    - **Find:** `source scripts/unity-versions.sh 2>/dev/null || true`
    - **Add above it:** `UNITY_TEST_VERSIONS=()`

- [ ] **Fix 3: Hardcoded Local Machine Paths in `generate-ai-context.sh`**
  - **File:** `scripts/generate-ai-context.sh`
  - **Issue:** The script contains hardcoded paths (`/home/i/Github/GC/src/GC.csproj`) to a local machine's directory. This is unportable and unprofessional.
  - **Action:** Delete the blocks relying on that specific directory.
    - **Delete:** Lines 20-23 (`if [ -f "/home/i/Github/GC/src/GC.csproj" ]; then ... fi`)
    - **Delete:** Line 77-78 (`elif [ -f "/home/i/Github/GC/src/GC.csproj" ]; then ...`)

## 🧹 Phase 2: Logic Sync & Cleanup

- [ ] **Fix 4: Fix Missing Samples Prompt in `setup.sh`**
  - **File:** `setup.sh`
  - **Issue:** `install.sh` correctly asks the user if they want to keep the `Samples~/` folder and deletes them if they don't. `setup.sh` is missing this feature entirely.
  - **Action 1 (Defaults):** Around line 77, where `FORCE_YES` and argument overrides are handled, add `SAMPLES="3"` inside the `if`, `elif`, and `elif` blocks.
  - **Action 2 (Prompt):** At the bottom of the prompt section (around line 118, right before `echo "  Package: $PACKAGE_ID"`), add the following interactive prompt:
    ```bash
    echo ""
    echo "  Create samples?"
    echo "  [1] None"
    echo "  [2] QuickStart scene"
    echo "  [3] QuickStart + UI Toolkit demo"
    read -rp "  Selection [3]: " SAMPLES
    SAMPLES="${SAMPLES:-3}"
    ```
  - **Action 3 (Cleanup Logic):** Just before `# ── Erase all traces ──` (around line 186), add the cleanup logic block:
    ```bash
    # ── Samples ─────────────────────────────────────────────────────
    if [ "$SAMPLES" = "1" ]; then
        rm -rf Samples~
        python3 -c "import json; d=json.load(open('package.json')); d.pop('samples',None); json.dump(d,open('package.json','w'),indent=2)" 2>/dev/null || true
    elif [ "$SAMPLES" = "2" ]; then
        rm -rf Samples~/UIToolkitDemo
        python3 -c "import json; d=json.load(open('package.json')); d['samples']=[s for s in d['samples'] if 'QuickStart' in s['path']]; json.dump(d,open('package.json','w'),indent=2)" 2>/dev/null || true
    fi
    ```

- [ ] **Fix 5: Delete the Correct Old Markdown File**
  - **Files:** `setup.sh`, `install.sh`, `scripts/test-template.sh`
  - **Issue:** These scripts try to clean up `TODO_GOD_TIER_UNITY_PACKAGE_TEMPLATE.md`, but the file was renamed to `TODO-FEATURES.md`.
  - **Action:** Search for `TODO_GOD_TIER_UNITY_PACKAGE_TEMPLATE.md` in those three files and replace the text exactly with `TODO-FEATURES.md`.

- [ ] **Fix 6: Remove `Tools~` on Minimal Install**
  - **File:** `install.sh`
  - **Issue:** In the `# ── Cleanup ──` section, the `--minimal` flag deletes dev-folders but forgets `Tools~`.
  - **Action:** Change `rm -rf Samples~ Documentation~ Skills~ Dev~/benchmarks Dev~/tools` to `rm -rf Samples~ Documentation~ Skills~ Dev~/benchmarks Dev~/tools Tools~`

## 🧩 Phase 3: Project Architecture

- [ ] **Fix 7: Generate Missing `.meta` Files**
  - **Issue:** Unity requires `.meta` files for all tracked assets, but the repository is missing them (e.g., for `Samples~/QuickStart/QuickStartSample.cs` and other files). 
  - **Action:** You don't need to write code. Run the helper script built into the repository to generate them automatically:
    `bash scripts/create-missing-meta.sh`

---

## 🧪 AI Verification Steps

Once you have completed all 7 fixes above, execute the following bash commands sequentially. **Do not mark your task as done until every single command exits with `0` (Success).**

```bash
# 1. Ensure all metadata files are generated and present
bash scripts/create-missing-meta.sh

# 2. Test CLI interactions (verifies setup.sh runs cleanly without prompts)
bash scripts/test-cli.sh

# 3. Test Template Generation (verifies the template replaces all tokens correctly)
bash scripts/test-template.sh

# 4. Test GameCI Staging (verifies the CI setup script no longer fails on placeholders)
bash scripts/stage-unity-package-test.sh .gameci/package-under-test

# 5. Check Compatibility Matrix (verifies the unbound variable fix)
bash scripts/generate-compatibility-matrix.sh

# 6. Run full project diagnostics (checks system, git config, and package integrity)
bash scripts/doctor.sh

# 7. Run full smoke test (Compiles code, runs tests, checks for DLL leaks, checks API diffs)
bash scripts/smoke.sh
