# Unity UPM Package Template — Agent Guide

## Architecture
Minimal Unity UPM package template. Compiles and tests outside Unity using `UnityMathematics.NoDeps` NuGet.

### Source layout
- `__PACKAGE__/Runtime/` — Unity package source (single source of truth)
- `__PACKAGE__/Tests/` — Unity tests
- `__PACKAGE__/Editor/` — Unity editor code
- `Dev~/src/__PACKAGE__/` — dotnet csproj that compiles `Runtime/**/*.cs`
- `Dev~/tests/__PACKAGE__.Tests/` — dotnet test project that compiles `Tests/**/*.cs`

### The math trick (three names, three places)
- **C# code**: `using Unity.Mathematics;`
- **dotnet csproj**: `UnityMathematics.NoDeps` NuGet with `PrivateAssets="All"` (all csprojs)
- **Unity**: `package.json` declares `"com.unity.mathematics": "1.3.2"`

All dotnet projects use `UnityMathematics.NoDeps`. Never plain `UnityMathematics`.

### NuGet setup
- Version centralized: `<UnityMathematicsVersion>` in `Directory.Build.props`
- `PrivateAssets="All"` on every PackageReference → compile only, never ship

### Unity consumption
- `package.json` declares `"com.unity.mathematics": "1.3.2"`
- `*.asmdef` references `Unity.Mathematics`

## Template system
- All files use `__PACKAGE__`, `__NAMESPACE__`, `__DISPLAY__`, `__AUTHOR__`, `__YEAR__`, `__UNITY_MIN__`, `__TEST_NET__` placeholders
- `install.sh` replaces tokens and renames folders
- `install.sh --yes` accepts all defaults

## Generated structure (after install.sh)
```
repo/
├── package.json
├── Runtime/            ← flattened from __PACKAGE__/Runtime/
├── Tests/              ← flattened from __PACKAGE__/Tests/
├── Editor/             ← flattened from __PACKAGE__/Editor/
├── Dev~/src/           ← dotnet build
├── Dev~/tests/         ← dotnet test
├── Dev~/infra/         ← slnx (hidden from Unity)
├── .gitignore
├── .gitattributes
├── LICENSE
└── README.md
```

## Rules
1. Never commit `Unity.Mathematics.dll`
2. Never commit `bin/`, `obj/`
3. Keep asmdef references synced with package.json dependencies
4. All dotnet csprojs use `UnityMathematics.NoDeps` (never plain `UnityMathematics`)
5. `Directory.Build.props` lives in `Dev~/src/` and `Dev~/tests/`
6. `~/` suffixed folders are hidden from Unity
