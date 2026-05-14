# Testing Skill

## Local
```bash
bash scripts/smoke.sh                    # Build + test + DLL leak
dotnet test -c Release                   # Just tests
bash scripts/doctor.sh                   # Full diagnostic
```

## CI
- `ci.yml`: dotnet build/test, DLL leak, placeholder scan, template self-test
- `unity-package-test.yml`: GameCI Unity package tests

## Test compaction
```bash
dotnet run --project tools/TestLogCompact -- --input Editor.log --stdout
dotnet run --project tools/TestResultsCompact -- --input TestResults.xml --stdout
```

## Writing tests
- Tests live in `<PackageID>.Tests/`
- Both Unity and dotnet compile the same test files
- Use NUnit `[Test]` fixtures
- Test files are shared: `tests/` csproj includes `../<PackageID>.Tests/**/*.cs`
