# TODO — BovineLabs Convention Alignment

## asmdef defaults
- [ ] 1. `autoReferenced: true` → `false` (all assemblies)
- [ ] 2. `allowUnsafeCode: false` → `true` (all assemblies)
- [ ] 3. Tests asmdef: `autoReferenced: false` already correct — verify
- [ ] 4. Editor asmdef: `autoReferenced: false` already correct — verify

## AssemblyInfo.cs
- [ ] 5. Add `AssemblyInfo.cs` to Runtime with `InternalsVisibleTo` for Tests, Editor, Debug
- [ ] 6. Template placeholder: `__PACKAGE__` in InternalsVisibleTo names

## SourceGenerator~ support
- [ ] 7. Add `SourceGenerator~/` folder with minimal placeholder csproj
- [ ] 8. csproj outputs to `<PackageRoot>/SourceGenerators/` on build
- [ ] 9. Add `SourceGenerator~` to `.gitignore` bin/obj exclusion check
- [ ] 10. Add `.meta` for `SourceGenerator~/` and `SourceGenerators/`

## Plugins~ support (optional skill/resource hosting)
- [ ] 11. Add `Plugins~/` folder with README explaining purpose
- [ ] 12. Add `.meta` for `Plugins~/`

## setup.sh / install.sh
- [ ] 13. Update generated README "Where code lives" table with new folders
- [ ] 14. Setup.sh cleanup logic: preserve SourceGenerator~ and Plugins~

## Tests & CI
- [ ] 15. Update test-template.sh structure checks
- [ ] 16. Update test-cli.sh assertions for new asmdef defaults
- [ ] 17. Update doctor.sh for new defaults (autoReferenced, allowUnsafeCode)
- [ ] 18. All 90 test-cli.sh tests pass
- [ ] 19. test-template.sh passes
- [ ] 20. smoke.sh passes
- [ ] 21. GitHub CI green (4/5 — unity-package-test needs secrets)
