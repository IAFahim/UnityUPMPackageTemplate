# Unity UPM Package Template

> **One command. Your Unity package. Done.**

```bash
bash <(curl -sL https://raw.githubusercontent.com/__AUTHOR__/UnityUPMPackageTemplate/main/install.sh)
```

Or clone and run locally:

```bash
git clone https://github.com/__AUTHOR__/UnityUPMPackageTemplate.git my-package
cd my-package && ./setup.sh
```

## What you get

```
my-package/
├── com.owner.pkg.Runtime/       ← Your code (Unity compiles this)
│   ├── Template.cs
│   └── *.Runtime.asmdef
├── com.owner.pkg.Tests/         ← Unity + CI tests
│   └── Template.Tests.cs
├── Dev~/
│   ├── src/                        ← dotnet project → points at Runtime/
│   ├── tests/                      ← dotnet test project → points at Tests/
│   ├── benchmarks/                 ← BenchmarkDotNet
│   └── tools/                      ← Build tools
├── Samples~/                     ← Unity importable samples
│   ├── QuickStart/
│   └── UIToolkitDemo/
├── Documentation~/               ← Package docs
│   ├── index.md
│   ├── installation.md
│   ├── quick-start.md
│   ├── api.md
│   └── release-notes.md
├── Skills~/                      ← AI agent skills
│   ├── unity-package/
│   ├── release-debugging/
│   ├── meta-files/
│   ├── gameci/
│   └── tests/
└── scripts/
    ├── smoke.sh                  ← Build + test + DLL leak check
    ├── doctor.sh                 ← Full environment diagnostic
    ├── validate-upm.sh           ← UPM package quality gate
    ├── verify-meta.sh            ← .meta file integrity checker
    ├── check-size.sh             ← Package size budget
    ├── generate-ai-context.sh    ← AI context dump
    ├── version.sh                ← Bump version everywhere
    └── test-template.sh          ← Meta-test: does the template work?
```

## Smart defaults

The installer **detects** everything it can:

| Input | Auto-detected from |
|---|---|
| Package ID | Folder name (if valid reverse-DNS) |
| Display name | Last segment of package ID, PascalCased |
| Author | `git config user.name` or GitHub login |
| C# namespace | Package ID → `Owner.PackageName` |
| GitHub owner | `gh api user` |
| Unity minimum | Scans `~/Unity/Hub/Editor/` |
| .NET SDK | `global.json` rollForward |

Just press Enter through everything. Or pass args:

```bash
./setup.sh com.owner.pkg "Display Name" "Author" "CSharp.Namespace"
```

## Scripts

| Command | What it does |
|---|---|
| `bash scripts/smoke.sh` | Build + test + DLL leak check |
| `bash scripts/doctor.sh` | 28+ environment + package diagnostics |
| `bash scripts/validate-upm.sh` | 26 UPM package structure checks |
| `bash scripts/verify-meta.sh` | .meta file integrity (GUIDs, orphans, dupes) |
| `bash scripts/check-size.sh [KB]` | Package size budget check (default 500KB) |
| `bash scripts/generate-ai-context.sh` | AI context dump (full + compact) |
| `bash scripts/version.sh 0.2.0` | Bump version in package.json |
| `bash scripts/test-template.sh` | Meta-test: creates fake package, verifies template works |

## Tools

| Tool | What it does |
|---|---|
| `TestLogCompact` | Unity Editor log → compact compile-error summary |
| `TestResultsCompact` | NUnit XML → compact failed-test summary |
| `UnityPackageExporter` | Editor script for .unitypackage export |
| `UnityMetaValidator` | .meta file validation (GUIDs, dupes, orphans) |

## CI Workflows

| Workflow | When | What |
|---|---|---|
| `ci.yml` | Every push/PR | dotnet build/test, DLL leak, placeholders, UPM validate, size check, self-test |
| `unity-package-test.yml` | Push to main/manual | GameCI Unity package tests (needs license secrets) |
| `unity-activation.yml` | Manual | Generate Unity license activation file |
| `release.yml` | Tag `v*` | Verify version, test, validate, size, AI context, GitHub release |
| `ai-context.yml` | Push/PR/manual | Generate AI context artifacts |

## Daily workflow

```bash
vim com.owner.pkg.Runtime/MyType.cs
bash scripts/doctor.sh
git push
```

Unity installs via git URL. **No DLLs. No adapters. Source is the package.**

## Release workflow

```bash
bash scripts/version.sh 0.2.0
git add -A && git commit -m "release 0.2.0"
git tag v0.2.0
git push --tags
# → CI validates → creates GitHub release with package zip + AI context
```

## GameCI setup

1. Run Actions → `unity-activation`
2. Download the `.alf` file
3. Convert to license at license.unity3d.com
4. Add secrets: `UNITY_LICENSE`, `UNITY_EMAIL`, `UNITY_PASSWORD`

## How the math trick works

```
Dev~/src/*.csproj:
  UnityMathematics NuGet → PrivateAssets="All" → compile only

CI:
  Builds Runtime/**/*.cs → IL references Unity.Mathematics by name
  Tests use UnityMathematics.NoDeps → no UnityEngine dependency

Unity:
  package.json → "com.unity.mathematics": "1.3.2"
  asmdef → references Unity.Mathematics
  noEngineReferences=true → runtime can't touch UnityEngine
  Same assembly name → Burst sees your source
```

## What's erased on install

After `setup.sh` or `install.sh` runs, template-only metadata is removed:
- ❌ No `setup.sh`, `install.sh`, `AGENTS.md`, `CHANGELOG.md`
- ❌ No `scripts/test-template.sh`, `scripts/test-cli.sh`
- ✅ GitHub workflows kept for CI/CD
- ✅ Scripts kept: `smoke.sh`, `doctor.sh`, `validate-upm.sh`, `version.sh`, etc.
- ✅ Full `Dev~/` bridge kept for outside-Unity development
- ✅ Build passes, tests pass

## License

MIT
