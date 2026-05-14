# Meta Files Skill

## Rules
- Every `.cs`, `.asmdef`, `.unity`, `.prefab`, `.uxml`, `.uss` needs a `.meta`
- GUIDs must be unique, lowercase hex, 32 characters
- Never hand-write scene/prefab `.meta` files — let Unity generate them
- Use `AssetDatabase` APIs for create/move/delete, not raw filesystem

## Validation
```bash
bash scripts/verify-meta.sh
dotnet run --project tools/UnityMetaValidator
```

## Repair
If `.meta` files are corrupted:
1. Open a temp Unity project
2. Copy assets into `Assets/`
3. Let Unity import and regenerate `.meta` files
4. Copy the validated `.meta` files back

## CI check
The release workflow validates `.meta` files before packaging.
