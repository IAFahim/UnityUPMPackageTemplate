# Unity UPM Package Template

> **Build outside Unity. Ship as a Unity package. No DLLs.**

A batteries-included template that scaffolds a complete Unity UPM package with CI, tests, benchmarks, docs, and an outside-Unity dev loop — all from one command.

## Quick start

```bash
# Option A: One-liner (creates a new folder)
bash <(curl -sL https://raw.githubusercontent.com/__AUTHOR__/UnityUPMPackageTemplate/main/install.sh) my-package

# Option B: Clone and run locally
git clone https://github.com/__AUTHOR__/UnityUPMPackageTemplate.git my-package
cd my-package && ./setup.sh
```

Both walk you through a few questions (package ID, author, namespace) with smart defaults. Press Enter to accept each one. When done, you have a fully working package that builds and passes tests.

## What is this?

This is a **template repository** — a starting point for creating Unity packages. You run it once, it generates your package, then you delete the template and work in your new package.

### The key idea

```
┌─────────────────────────────────────────────────────────┐
│  Your package repo (what gets generated)                 │
│                                                          │
│  com.owner.pkg/               ← Single package root     │
│    Runtime/                    ← Your code lives HERE    │
│    Tests/                      ← Your tests live HERE    │
│    Editor/                     ← Your editor code HERE   │
│                                                          │
│  Dev~/src/                    ← dotnet project that      │
│                                 compiles Runtime/**/*.cs │
│                                 (no Unity needed)        │
│                                                          │
│  Dev~/tests/                  ← dotnet test project that │
│                                 compiles Tests/**/*.cs   │
│                                                          │
│  package.json                 ← Unity sees this as a UPM │
│                                 package via git URL      │
└─────────────────────────────────────────────────────────┘
```

You write code **once** in `Runtime/`. Two consumers compile it:
- **dotnet CLI** (for CI, local dev, fast iteration) via `Dev~/src/`
- **Unity** (for actual usage) via UPM git URL

No DLLs. No adapters. Source is the package.

## Generated folder structure

After running `setup.sh` or `install.sh`, you get:

```
my-package/
├── com.owner.pkg/                   ← YOUR PACKAGE (Unity compiles this)
│   ├── Runtime/                       Runtime types + asmdef
│   │   ├── MyType.cs                    Replace the placeholder files
│   │   └── com.owner.pkg.asmdef         with your own types.
│   ├── Tests/                        ← YOUR TESTS (Unity + dotnet)
│   │   ├── MyType.Tests.cs              Shared by both Unity and CI.
│   │   └── com.owner.pkg.Tests.asmdef
│   └── Editor/                       ← YOUR EDITOR CODE (optional)
│       └── com.owner.pkg.Editor.asmdef
│
├── Samples~/                       ← Importable samples (optional)
│   ├── QuickStart/
│   └── UIToolkitDemo/
│
├── Dev~/                           ← dotnet bridge (hidden from Unity)
│   ├── src/                          csproj → compiles Runtime/**/*.cs
│   ├── tests/                        csproj → compiles Tests/**/*.cs
│   ├── benchmarks/                   BenchmarkDotNet
│   └── tools/                        Build tools (meta validator, etc.)
│
├── Documentation~/                 ← Package docs (MkDocs)
├── Skills~/                        ← AI agent skill files
├── Tools~/                         ← IDE snippets (Rider, VS Code)
│
├── scripts/                        ← Automation
│   ├── smoke.sh                      Build + test + DLL leak check
│   ├── doctor.sh                     Full diagnostic (28+ checks)
│   ├── version.sh                    Bump version everywhere
│   └── ...                           validate, verify, release, etc.
│
├── .github/workflows/              ← CI/CD
│   ├── ci.yml                        Build, test, validate on every push
│   ├── release.yml                   GitHub release on tag
│   └── ...                           Unity tests, docs, AI context
│
├── package.json                    ← UPM manifest (name, version, deps)
├── Directory.Build.props           ← Shared build settings
└── README.md                       ← Auto-generated for your package
```

## Where do I put my code?

| I want to... | Put it in... | Why |
|---|---|---|
| Add a runtime type | `com.owner.pkg/Runtime/` | Unity compiles this folder |
| Add a runtime test | `com.owner.pkg/Tests/` | Shared by Unity + dotnet CI |
| Add an editor window | `com.owner.pkg/Editor/` | Editor-only platform |
| Add a sample | `Samples~/MySample/` | Users import via Package Manager |
| Add a benchmark | `Dev~/benchmarks/` | BenchmarkDotNet, dev-only |
| Add docs | `Documentation~/` | MkDocs site |

## How the dev loop works

### Without Unity (fast)

```bash
# Edit your code
vim com.owner.pkg.Runtime/MyType.cs
vim com.owner.pkg.Tests/MyType.Tests.cs

# Build and test instantly (no Unity needed)
dotnet test -c Release

# Full validation
bash scripts/smoke.sh
```

### With Unity

1. Push your repo to GitHub
2. In Unity: Package Manager → Add from git URL → paste your repo URL
3. Unity imports `com.owner.pkg.Runtime/` as a package
4. That's it. Same source, no DLLs.

### How the math trick works

The template uses `Unity.Mathematics` for types like `float3`, `int2`, etc. But it compiles outside Unity:

```
Dev~/src/*.csproj:
  UnityMathematics NuGet → PrivateAssets="All" → compile-only, never copied

CI (dotnet):
  Builds Runtime/**/*.cs → references Unity.Mathematics by assembly name
  Tests use UnityMathematics.NoDeps → no UnityEngine dependency needed

Unity:
  package.json → "com.unity.mathematics": "1.3.2"
  asmdef → references Unity.Mathematics
  noEngineReferences=true → runtime can't touch UnityEngine
  Same assembly name in both → Burst sees your source
```

## Using the template

### Interactive (recommended)

```bash
bash <(curl -sL https://raw.githubusercontent.com/__AUTHOR__/UnityUPMPackageTemplate/main/install.sh)
```

Asks 7 questions with smart auto-detected defaults:

| Question | Auto-detected from |
|---|---|
| Folder name | Current directory name |
| Package ID | Folder name (if valid reverse-DNS) |
| Display name | Last segment of package ID, PascalCased |
| Author | `git config user.name` or `gh api user` |
| C# namespace | Package ID segments, PascalCased |
| Unity minimum | Scans `~/Unity/Hub/Editor/` |
| Samples | Default: QuickStart + UI Toolkit demo |

Press Enter to accept each default.

### CLI args (no prompts)

```bash
# install.sh with folder name
bash <(curl -sL .../install.sh) my-folder

# setup.sh with all args
./setup.sh com.owner.pkg "Display Name" "Author" "CSharp.Namespace"
```

### Flags

```bash
bash install.sh --yes        # Accept all defaults
bash install.sh --minimal    # Strip benchmarks, tools, docs, samples
```

## Day-to-day workflow

```bash
# Write code
vim com.owner.pkg.Runtime/MyType.cs

# Test locally (fast, no Unity)
dotnet test -c Release

# Validate everything
bash scripts/smoke.sh

# Commit and push
git push
# → CI runs automatically
```

## Release workflow

```bash
bash scripts/version.sh 0.2.0           # Bump version + changelog
bash scripts/pre-release.sh 0.2.0       # Full checklist (11 checks)
git tag v0.2.0 && git push --tags       # Triggers release CI
```

CI validates → creates GitHub release with package zip + AI context.

## Scripts reference

| Command | What it does |
|---|---|
| `bash scripts/smoke.sh` | Build + test + coverage + API diff + validate |
| `bash scripts/doctor.sh` | 28+ environment and package diagnostics |
| `bash scripts/validate-upm.sh` | UPM structure quality gate |
| `bash scripts/verify-meta.sh` | .meta file integrity (GUIDs, orphans, dupes) |
| `bash scripts/check-size.sh [KB]` | Package size budget (default 500KB) |
| `bash scripts/version.sh 0.2.0` | Bump version in package.json + changelog |
| `bash scripts/pre-release.sh 0.2.0` | Full pre-release checklist |
| `bash scripts/api-diff.sh` | Detect breaking API changes |
| `bash scripts/bench.sh [filter]` | Run benchmarks |
| `bash scripts/test-template.sh` | Self-test: generates a test package, verifies it works |

## CI/CD

| Workflow | Trigger | What |
|---|---|---|
| `ci.yml` | Every push/PR | Build, test, DLL leak, placeholders, UPM validate, size, self-test |
| `template-self-test.yml` | Every push/PR | Generates a package from template, verifies it |
| `release.yml` | Tag `v*` | Validate, test, benchmark, GitHub release |
| `unity-package-test.yml` | Push to main | GameCI Unity tests (needs license secrets) |
| `docs.yml` | Push to main | Build and deploy docs to GitHub Pages |
| `ai-context.yml` | Push/PR | Generate AI context artifacts |

### GameCI setup (for Unity testing in CI)

1. Run Actions → `unity-activation` → download `.alf` file
2. Convert at [license.unity3d.com/manual](https://license.unity3d.com/manual)
3. Add secrets: `UNITY_LICENSE`, `UNITY_EMAIL`, `UNITY_PASSWORD`

See [`.github/UNITY_CI_SETUP.md`](.github/UNITY_CI_SETUP.md) for details.

## What gets removed after generation

After `setup.sh` or `install.sh` runs, template metadata is cleaned up:

- ❌ `setup.sh`, `install.sh` — template scaffolding, not needed
- ❌ `AGENTS.md`, `CHANGELOG.md` — template-only docs
- ❌ `scripts/test-template.sh`, `scripts/test-cli.sh` — meta-tests
- ✅ All CI workflows kept
- ✅ All scripts kept (`smoke.sh`, `doctor.sh`, `version.sh`, etc.)
- ✅ Full `Dev~/` bridge kept
- ✅ Build passes, tests pass

## Extending the template

### Adding a new dependency

1. Add to `package.json` → `dependencies`
2. Add to the Runtime `.asmdef` → `references`
3. Add NuGet package to `Dev~/src/*.csproj` (with `PrivateAssets="All"`)

### Adding a new assembly

1. Create `com.owner.pkg.NewAssembly/` with code + `.asmdef`
2. Create `Dev~/src/subproject/*.csproj` pointing at it
3. Add project to `.slnx`

## License

MIT
