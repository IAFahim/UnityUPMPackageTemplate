# TODO — BovineLabs Convention Alignment

## asmdef defaults
- [x] 1. `autoReferenced: true` → `false` (all assemblies)
- [x] 2. `allowUnsafeCode: false` → `true` (all assemblies)
- [x] 3. Tests asmdef: `autoReferenced: false` — verified
- [x] 4. Editor asmdef: `autoReferenced: false` — verified

## AssemblyInfo.cs
- [x] 5. Add `AssemblyInfo.cs` to Runtime with `InternalsVisibleTo` for Tests, Editor
- [x] 6. Template placeholder: `__PACKAGE__` in InternalsVisibleTo names

## SourceGenerator~ support
- [x] 7. Add `SourceGenerator~/` folder with minimal placeholder csproj
- [ ] 8. csproj outputs to `<PackageRoot>/SourceGenerators/` on build (deferred — needs per-package config)
- [x] 9. Add `SourceGenerator~` to `.gitignore` bin/obj exclusion check
- [x] 10. Add `.meta` for `SourceGenerator~/`

## Plugins~ support
- [x] 11. Add `Plugins~/` folder with README explaining purpose
- [x] 12. Add `.meta` for `Plugins~/`

## setup.sh / install.sh
- [x] 13. Update generated README "Where code lives" table with new folders
- [x] 14. Setup.sh cleanup logic: preserve SourceGenerator~ and Plugins~

## Tests & CI
- [x] 15. Update test-template.sh structure checks
- [x] 16. Update test-cli.sh assertions for new asmdef defaults
- [x] 17. Update doctor.sh for new defaults (autoReferenced, allowUnsafeCode)
- [x] 18. All 92 test-cli.sh tests pass
- [x] 19. test-template.sh passes
- [x] 20. smoke.sh passes
- [x] 21. GitHub CI green (4/5 — unity-package-test needs secrets)
