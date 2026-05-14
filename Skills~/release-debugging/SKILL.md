# Release Debugging Skill

## Before changing code
1. `bash scripts/doctor.sh` — full diagnostic
2. `bash scripts/smoke.sh` — build + test + DLL leak
3. Check Unity CI logs → `artifacts/unity-editor.compact.txt`
4. Check test results → `artifacts/TestResults.compact.txt`

## Common failures
- **Build fails**: Check `Directory.Build.props` version matches csproj references
- **DLL leak**: `UnityMathematics` must have `PrivateAssets="All"` in ALL csprojs
- **Placeholder scan fails**: All `__X__` tokens must be replaced by setup.sh
- **Meta file issues**: Run `bash scripts/verify-meta.sh`
- **Version mismatch**: Tag version must match `package.json` version exactly

## Release flow
```bash
bash scripts/version.sh 0.2.0
git add -A && git commit -m "release 0.2.0"
git tag v0.2.0
git push --tags
```
CI validates → creates GitHub release with package zip.
