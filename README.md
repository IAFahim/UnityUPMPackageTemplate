# Unity UPM Package Template

Create Unity packages that feel like normal .NET projects.

**One command. Done.**

```bash
bash <(curl -sL https://raw.githubusercontent.com/IAFahim/UnityUPMPackageTemplate/main/install.sh)
```

Or clone and run locally:

```bash
git clone https://github.com/IAFahim/UnityUPMPackageTemplate.git my-package
cd my-package
./setup.sh
```

## What it creates

```
my-package/
├── com.company.packagename.Runtime/   ← Your code lives here
│   ├── Template.cs                     ← Replace with your types
│   └── *.Runtime.asmdef
├── com.company.packagename.Tests/     ← Tests (CI + Unity)
│   └── Template.Tests.cs
├── src/                                ← dotnet project (points at Runtime/)
├── tests/                              ← dotnet test project (points at Tests/)
├── benchmarks/                         ← BenchmarkDotNet
├── package.json                        ← UPM manifest
└── *.slnx                              ← Solution file
```

## Daily workflow

```bash
vim com.company.packagename.Runtime/MyType.cs
dotnet test -c Release
git push
```

Unity installs via git URL. No DLLs. No adapters. Source is the package.

## How the trick works

```
Directory.Build.props:
  UnityMathematics NuGet → PrivateAssets="All" → compile only, never shipped

CI:
  dotnet builds Runtime/*.cs → IL references "Unity.Mathematics" by name
  Tests use UnityMathematics.NoDeps → no UnityEngine needed

Unity:
  package.json → "com.unity.mathematics": "1.2.6"
  asmdef → references Unity.Mathematics
  Same assembly name → no duplicate, Burst works
```

## Features

| Feature | Command |
|---|---|
| Build | `dotnet build -c Release` |
| Test | `dotnet test -c Release` |
| Benchmark | `dotnet run -c Release --project benchmarks/` |
| CI | Push to GitHub — Actions runs automatically |
| Unity install | Package Manager → git URL |
