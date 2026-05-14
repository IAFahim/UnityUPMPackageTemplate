#!/usr/bin/env bash
set -euo pipefail
dotnet restore *.slnx
dotnet build *.slnx -c Release --no-restore
dotnet test *.slnx -c Release --no-build
echo ""
echo "Checking for Unity.Mathematics DLL leak..."
LEAKS=$(find . -path '*/bin' -prune -o -path '*/obj' -prune -o -path './.git' -prune \
    -o -name 'Unity.Mathematics*.dll' -print 2>/dev/null)
if [ -n "$LEAKS" ]; then
    echo "FAIL: Unity.Mathematics DLL found!"
    echo "$LEAKS"
    exit 1
fi
echo "OK: All tests pass, no DLL leak."
