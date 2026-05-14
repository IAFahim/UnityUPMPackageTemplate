$ErrorActionPreference = "Stop"
dotnet restore *.slnx
dotnet build *.slnx -c Release --no-restore
dotnet test *.slnx -c Release --no-build
Write-Host ""
Write-Host "Checking for Unity.Mathematics DLL leak..."
$found = Get-ChildItem -Path src -Filter "Unity.Mathematics*" -Recurse -ErrorAction SilentlyContinue
if ($found) {
    Write-Host "FAIL: Unity.Mathematics DLL found in output!"
    $found | ForEach-Object { Write-Host $_.FullName }
    exit 1
}
Write-Host "OK: All tests pass, no DLL leak."
