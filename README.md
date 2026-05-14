# Unity UPM Package Template

> **One command. Your Unity package. Done.**

```bash
bash <(curl -sL https://raw.githubusercontent.com/IAFahim/UnityUPMPackageTemplate/main/install.sh)
```

Or clone and run locally:

```bash
git clone https://github.com/IAFahim/UnityUPMPackageTemplate.git my-package
cd my-package && ./setup.sh
```

## What you get

```
my-package/
├── com.owner.pkg.Runtime/       ← Your code (Unity compiles this)
│   ├── Template.cs               ← Replace with your types
│   └── *.Runtime.asmdef
├── com.owner.pkg.Tests/         ← Unity + CI tests
│   └── Template.Tests.cs
├── src/                          ← dotnet project → points at Runtime/
├── tests/                        ← dotnet test project → points at Tests/
├── benchmarks/                   ← BenchmarkDotNet
├── package.json                  ← UPM manifest
├── Samples~/                     ← Unity importable samples
├── Documentation~/               ← Unity docs
└── scripts/
    ├── smoke.sh                  ← Build + test + DLL leak check
    ├── doctor.sh                 ← Full environment diagnostic
    ├── validate-upm.sh           ← UPM package quality gate
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
| `bash scripts/doctor.sh` | Full environment + package diagnostic |
| `bash scripts/validate-upm.sh` | UPM package structure validator |
| `bash scripts/version.sh 0.2.0` | Bump version in package.json |
| `bash scripts/test-template.sh` | Meta-test: creates fake package, verifies template works |

## CI Workflows

| Workflow | When | What |
|---|---|---|
| `ci.yml` | Every push/PR | dotnet build/test, DLL leak check, placeholder scan, template self-test |
| `unity-package-test.yml` | Push to main/manual | GameCI Unity package tests (needs license secrets) |
| `unity-activation.yml` | Manual | Generate Unity license activation file |
| `release.yml` | Tag `v*` | Verify version, test, create GitHub release with archive |

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
# → CI validates, creates GitHub release with package zip
```

## How the math trick works

```
src/*.csproj:
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

After `setup.sh` or `install.sh` runs, **zero template traces** remain:
- ❌ No `setup.sh`, `install.sh`, `AGENTS.md`, `CHANGELOG.md`
- ❌ No GameCI workflows (need Unity license secrets)
- ❌ No sample code or template documentation
- ❌ No template skip-check in CI
- ✅ Core CI workflow kept (cleaned of template fingerprints)
- ✅ Scripts kept: `smoke.sh`, `doctor.sh`, `validate-upm.sh`, `version.sh`
- ✅ Clean `init` commit
- ✅ Build passes, tests pass

## License

MIT
