# Unity CI Setup Guide

This guide explains how to set up GameCI for your Unity package.

## 1. Automated Setup (Recommended)

If you have the [GitHub CLI](https://cli.github.com) installed and authenticated:

```bash
./scripts/setup-secrets.sh
```

This script will prompt you for your Unity credentials and store them securely in GitHub Secrets.

## 2. Manual Setup

If you prefer manual setup, add the following secrets to **GitHub → Settings → Secrets and variables → Actions**:

| Secret | Description | Required |
|--------|-------------|----------|
| `UNITY_EMAIL` | Your Unity account email | Yes |
| `UNITY_PASSWORD` | Your Unity account password | Yes |
| `UNITY_LICENSE` | Your Unity license file content (`.ulf`) | Yes |
| `UNITY_SERIAL` | Your Unity Pro serial number | Pro only |

## 3. How to get `UNITY_LICENSE`

### For Unity Personal

1. Go to your repository on GitHub.
2. Go to **Actions** → **unity-activation**.
3. Click **Run workflow** → **Run workflow**.
4. Wait for it to finish.
5. Download the `unity-activation-file` artifact (it contains a `.alf` file).
6. Go to [license.unity3d.com/manual](https://license.unity3d.com/manual).
7. Upload your `.alf` file.
8. Download the resulting `.ulf` file.
9. Open the `.ulf` file in a text editor.
10. Copy the entire XML content.
11. Add it as a GitHub secret named `UNITY_LICENSE`.

### For Unity Pro

You can usually use `UNITY_SERIAL` along with `UNITY_EMAIL` and `UNITY_PASSWORD`. Some versions might still require a license file.

## 4. Verifying Secrets

Run the audit script to check if your secrets are correctly set:

```bash
./scripts/check-secrets.sh
```

## 5. Security Note

- **Never** commit your `.ulf` or `.alf` files to the repository.
- Secrets are encrypted and only accessible by GitHub Actions.
- If you suspect your secrets are compromised, rotate them immediately in GitHub settings.
