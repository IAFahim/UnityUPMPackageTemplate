# AGENTS.md — Unity Package Template Architecture

This document teaches AI agents (and humans) how this template works, where to put code, and how to extend it.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        EDIT CODE HERE                           │
│                                                                 │
│  PackageName.Runtime/                                           │
│    YourType.cs           ← Source files. Unity.Mathematics OK.  │
│    PackageName.Runtime.asmdef                                   │
│                                                                 │
│  PackageName.Tests/                                             │
│    YourTypeTests.cs       ← Tests that run in BOTH CI + Unity  │
│    PackageName.Tests.asmdef                                     │
│                                                                 │
│  package.json            ← UPM manifest                         │
│  README.md               ← User-facing docs                     │
│  CHANGELOG.md            ← Version history                      │
│  LICENSE                 ← MIT by default                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
   ┌──────────┐      ┌──────────────┐     ┌──────────────┐
   │  dotnet  │      │  dotnet CI   │     │   Unity UPM  │
   │  build   │      │  test + pack │     │  git install │
   │          │      │              │     │              │
   │ src/     │      │ tests/       │     │ asmdef +     │
   │ csproj → │      │ NUnit +      │     │ package.json │
   │ links to │      │ UnityMath    │     │ → Unity      │
   │ Runtime/ │      │ .NoDeps      │     │ resolves     │
   └──────────┘      └──────────────┘     │ com.unity.   │
                                         │ mathematics  │
                                         └──────────────┘
```

## File map

```
unity-package-template/
│
├── AGENTS.md                          ← YOU ARE HERE
├── README.md                          ← User-facing README
├── LICENSE                            ← MIT
├── CHANGELOG.md                       ← Version history (keep updated)
├── setup.sh                           ← One-time: replaces placeholder names
│
├── Directory.Build.props              ← Shared: UnityMathematics NuGet, PrivateAssets="All"
├── global.json                        ← SDK version pinning
├── PackageName.slnx                   ← Solution file
│
├── src/PackageName/                   ← CI compilation project
│   └── PackageName.csproj             └── Compiles ../../PackageName.Runtime/*.cs
│
├── tests/PackageName.Tests/           ← CI test project
│   ├── PackageName.Tests.csproj       └── UnityMathematics.NoDeps + NUnit
│   └── *.Tests.cs                     └── Test files (shared with Unity via symlink or copy)
│
├── benchmarks/PackageName.Benchmarks/ ← Optional benchmarks
│   ├── PackageName.Benchmarks.csproj
│   └── *.Benchmarks.cs
│
├── PackageName.Runtime/               ← ★ SOURCE LIVES HERE ★
│   ├── PackageName.Runtime.asmdef     └── references: ["Unity.Mathematics"]
│   └── *.cs                           └── Your code. Use int2, int3, float3 freely.
│
├── PackageName.Tests/                 ← Unity test assembly
│   ├── PackageName.Tests.asmdef       └── references: ["PackageName.Runtime", "Unity.Mathematics"]
│   └── *.Tests.cs                     └── Same test files as CI
│
├── .github/workflows/
│   └── ci.yml                         ← dotnet test + verify no math DLL leak
│
└── scripts/
    └── smoke.sh                       ← Local: build + test + verify
```

## The NuGet trick (critical)

```
Directory.Build.props:
  <PackageReference Include="UnityMathematics" Version="1.3.2" PrivateAssets="All" />
                                                        ^^^^^^^^^^^^^^^^^^
                                                        Compile ONLY.
                                                        DLL never appears in output.

CI path:
  csproj → compiles Runtime/*.cs → IL references "Unity.Mathematics" by assembly name
  Tests use UnityMathematics.NoDeps → runs without UnityEngine.dll

Unity path:
  package.json → "com.unity.mathematics": "1.2.6"
  asmdef → references: ["Unity.Mathematics"]
  Unity resolves the same assembly by name → no duplicate DLL, Burst works

Why PrivateAssets="All" matters:
  Without it, dotnet would copy Unity.Mathematics.dll into your output.
  If that DLL ends up inside Unity → duplicate assembly error.
  PrivateAssets="All" = "I need this to compile, but don't ship it."
```

## Conventions

### Where to add a new type

1. Create `PackageName.Runtime/YourType.cs`
2. That's it. `src/PackageName.csproj` picks it up via `<Compile Include="../../PackageName.Runtime/*.cs" />`

### Where to add tests

1. Create `PackageName.Tests/YourTypeTests.cs` (Unity tests)
2. Create `tests/PackageName.Tests/YourTypeTests.cs` (CI tests)
3. Keep them in sync, or use the same file if tests don't need Unity-specific APIs

### What you can use in Runtime/

- `Unity.Mathematics` (`int2`, `float3`, `math.sin`, etc.) ✅
- `System.*` namespaces ✅
- Pure C# math ✅
- `UnityEngine` ❌ (not available in CI)
- `Unity.Collections` ❌ (not available in CI — add to tests only if needed)
- `Unity.Burst` ❌ (attribute only works inside Unity — use `[MethodImpl]` for CI)

### Naming

- C# namespace: `CompanyName.PackageName` (e.g., `BovineLabs.Grid.Pathfinding`)
- Assembly name: matches the asmdef name
- Package ID: `com.company.packagename` (reverse DNS)
- File names: `TypeName.cs` / `TypeName.Tests.cs`

### Versioning

Follow `package.json` version. Use semver:
- `0.1.0-alpha.1` during development
- `0.1.0` for first stable
- Bump in BOTH `package.json` and `Directory.Build.props` if versioned there

## Adding dependencies

### Unity package dependency

Edit `package.json`:
```json
"dependencies": {
    "com.unity.mathematics": "1.2.6",
    "com.unity.collections": "2.1.4"
}
```

Edit `PackageName.Runtime.asmdef`:
```json
"references": ["Unity.Mathematics", "Unity.Collections"]
```

For CI, add to `Directory.Build.props` or the csproj:
```xml
<PackageReference Include="UnityMathematics" Version="1.3.2" PrivateAssets="All" />
```

### Pure NuGet dependency (no Unity equivalent)

Add to `src/PackageName/PackageName.csproj`:
```xml
<PackageReference Include="SomePureLibrary" Version="1.0.0" />
```

⚠️ This means the DLL ships inside Unity. Only do this for pure .NET Standard libraries.

## CI pipeline

```yaml
# .github/workflows/ci.yml
- dotnet restore
- dotnet build -c Release
- dotnet test -c Release
- Verify no Unity.Mathematics DLL in output
```

CI proves:
1. Code compiles outside Unity
2. Tests pass
3. No leaky Unity DLLs

Unity proves:
1. Code compiles inside Unity (asmdef + package.json)
2. Burst can optimize (source-level access)
3. Editor tests pass

Both are needed. Neither alone is sufficient.

## Common mistakes

| Mistake | Fix |
|---|---|
| `PrivateAssets="All"` missing from UnityMathematics | DLL leaks into output → duplicate in Unity |
| Adding `[BurstCompile]` in Runtime/ | Burst attributes not in CI → compilation fails. Add `#if UNITY` guards |
| Forgetting to update asmdef references | New type uses new assembly → Unity can't resolve |
| Editing files in `src/` | Source lives in Runtime/ only. `src/` is just the csproj that points at Runtime/ |
| Test file in CI but not in Unity Tests/ | Test only runs in CI, not in Unity Editor |
