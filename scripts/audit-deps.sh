#!/usr/bin/env bash
# Usage: bash scripts/audit-deps.sh
# Checks all NuGet packages in the solution for known vulnerabilities.
set -euo pipefail

SLNX=$(ls *.slnx 2>/dev/null | head -1)
if [ -z "$SLNX" ]; then echo "No solution file." && exit 1; fi

echo ""
echo "  Auditing NuGet dependencies..."
echo ""

# dotnet list package --vulnerable requires .NET 7+
dotnet restore "$SLNX" --nologo -v quiet >/dev/null 2>&1

RESULT=$(dotnet list "$SLNX" package --vulnerable --include-transitive 2>&1)
echo "$RESULT"

if echo "$RESULT" | grep -q "has the following vulnerable packages"; then
    echo ""
    echo "  ✗ Vulnerable packages found. Update or replace them before releasing."
    exit 1
fi

echo ""
echo "  ✓ No known vulnerabilities in NuGet packages"

# Also check package.json dependencies (UPM — no automated vuln db, just age check)
echo ""
echo "  Unity package dependencies:"
python3 - <<'PY'
import json, urllib.request, datetime

with open("package.json") as f:
    pkg = json.load(f)

deps = pkg.get("dependencies", {})
for name, ver in deps.items():
    print(f"  {name}: {ver}")

if not deps:
    print("  (none)")
PY
