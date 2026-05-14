# Unity Package Development Skill

## Architecture
- Source lives in `<PackageID>.Runtime/` — this IS the Unity package
- `src/` csproj compiles Runtime/**/*.cs for dotnet CI (no Unity needed)
- `tests/` csproj compiles Tests/**/*.cs for dotnet CI
- Unity consumes the Runtime/ folder directly via UPM git URL
- `package.json` → UPM manifest, `*.asmdef` → assembly definitions

## Conventions
- `noEngineReferences: true` on Runtime asmdef — no UnityEngine access
- `AssemblyName` in csproj must match asmdef name exactly
- `UnityMathematics` NuGet: `PrivateAssets="All"` — compile only, never ship
- `UnityMathematics.NoDeps` for tests — no UnityEngine dependency
- Version centralized in `Directory.Build.props` as `$(UnityMathematicsVersion)`

## Before answering
1. Run `bash scripts/doctor.sh` — verify environment
2. Run `bash scripts/smoke.sh` — verify build + tests
3. Never commit `Unity.Mathematics.dll`
4. Never commit `bin/`, `obj/`, `Library/`, `Temp/`
5. Keep asmdef references synced with package.json dependencies
