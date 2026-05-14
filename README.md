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
├── com.owner.pkg.Runtime/    ← Your code (Unity compiles this)
│   ├── Template.cs            ← Replace with your types
│   └── *.Runtime.asmdef
├── com.owner.pkg.Tests/      ← Unity + CI tests
│   └── Template.Tests.cs
├── src/                       ← dotnet project → points at Runtime/
├── tests/                     ← dotnet test project → points at Tests/
├── benchmarks/                ← BenchmarkDotNet
├── package.json               ← UPM manifest
└── *.slnx                     ← Solution file
```

## Smart defaults

The installer **detects** everything it can:

| Input | Auto-detected from |
|---|---|
| Package ID | Folder name (if it's a valid ID) |
| Display name | Last segment of package ID, PascalCased |
| Author | `git config user.name` or GitHub login |
| C# namespace | Package ID → `Owner.PackageName` |
| GitHub owner | `gh api user` |
| Unity minimum | Scans `~/Unity/Hub/Editor/` |

Just press Enter through everything. Or pass args:

```bash
./setup.sh com.owner.pkg "Display Name" "Author" "CSharp.Namespace"
```

## Daily workflow

```bash
vim com.owner.pkg.Runtime/MyType.cs
dotnet test -c Release
git push
```

Unity installs via git URL. **No DLLs. No adapters. Source is the package.**

## How the math trick works

```
src/*.csproj:
  UnityMathematics NuGet → PrivateAssets="All" → compile only

CI:
  Builds Runtime/*.cs → IL references Unity.Mathematics by name
  Tests use UnityMathematics.NoDeps → no UnityEngine dependency

Unity:
  package.json → "com.unity.mathematics": "1.3.2"
  asmdef → references Unity.Mathematics
  Same assembly name → Burst sees your source
```

## What's erased on install

After `setup.sh` or `install.sh` runs, **zero traces** remain:
- ❌ No `setup.sh`, `install.sh`, `AGENTS.md`, `CHANGELOG.md`
- ❌ No `.github/` (CI is regenerated clean)
- ❌ No template references in README
- ✅ Clean `init` commit
- ✅ Build passes, tests pass

## License

MIT
