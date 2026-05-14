#!/usr/bin/env bash
set -euo pipefail
dotnet restore *.slnx
dotnet build *.slnx -c Release --no-restore
dotnet test *.slnx -c Release --no-build
echo ""
echo "Checking for Unity.Mathematics DLL leak..."
if find src -name "Unity.Mathematics*" -type f 2>/dev/null | grep -q .; then
    echo "FAIL: Unity.Mathematics DLL found in output!"
    exit 1
fi
echo "OK: All tests pass, no DLL leak."
