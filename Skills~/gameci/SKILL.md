# GameCI Skill

## Setup
1. Run `unity-activation` workflow → download `.alf` file
2. Convert `.alf` to Unity license at license.unity3d.com
3. Add repository secrets: `UNITY_LICENSE`, `UNITY_EMAIL`, `UNITY_PASSWORD`

## Workflows
- `unity-package-test.yml` — GameCI test runner with `packageMode: true`
- `unity-activation.yml` — Generate activation file for license setup
- Matrix tests across Unity 2022.3 and Unity 6

## Caveats
- Package cannot be at repo root — workflow copies to `.gameci/package-under-test/`
- Linux runners required (ubuntu-latest)
- Personal license: `UNITY_LICENSE` (file content)
- Pro license: `UNITY_EMAIL`, `UNITY_PASSWORD`, `UNITY_SERIAL`

## Troubleshooting
- If activation fails, the license file may have expired — re-run activation
- If tests hang, check that `testMode` is set correctly (All/EditMode/PlayMode)
