# Unity UPM Package Template — Agent Guide

## Architecture
This is a **Unity UPM package template** that compiles and tests outside Unity using `UnityMathematics` NuGet.

### Source layout
- `__PACKAGE__.Runtime/` — Unity package source (single source of truth)
- `src/__PACKAGE__/` — dotnet csproj that compiles `Runtime/**/*.cs` via `<Compile Include>`
- `tests/__PACKAGE__.Tests/` — dotnet test project that compiles `Tests/**/*.cs`
- `benchmarks/__PACKAGE__.Benchmarks/` — BenchmarkDotNet

### NuGet trick
- `src/*.csproj`: `UnityMathematics` with `PrivateAssets="All"` — compile only, never ship
- `tests/*.csproj`: `UnityMathematics.NoDeps` with `PrivateAssets="All"`
- Version centralized: `<UnityMathematicsVersion>` in `Directory.Build.props`

### Unity consumption
- `package.json` declares `"com.unity.mathematics": "1.3.2"`
- `*.asmdef` has `noEngineReferences: true`
- Assembly name in csproj matches asmdef name exactly

## Template system
- All files use `__PACKAGE__`, `__NAMESPACE__`, `__DISPLAY__`, `__AUTHOR__`, `__YEAR__`, `__UNITY_MIN__` placeholders
- `setup.sh` / `install.sh` replaces tokens and renames folders
- CI skips placeholder check when `__PLACEHOLDER__.cs` files exist (raw template)
- `scripts/test-template.sh` validates the template itself end-to-end

## Scripts
- `scripts/smoke.sh` — Build + test + DLL leak
- `scripts/doctor.sh` — Full diagnostic (28+ checks)
- `scripts/validate-upm.sh` — UPM structure validation
- `scripts/verify-meta.sh` — .meta file integrity
- `scripts/check-size.sh` — Package size budget
- `scripts/generate-ai-context.sh` — AI context dump
- `scripts/version.sh` — Version bump
- `scripts/test-template.sh` — Meta self-test

## Rules
1. Never commit `Unity.Mathematics.dll`
2. Never commit `bin/`, `obj/`, `Library/`, `Temp/`
3. Keep asmdef references synced with package.json dependencies
4. Run `bash scripts/smoke.sh` before final answer
5. Use `escape_sed()` for all sed replacements
