dotnet restore *.slnx
dotnet build *.slnx -c Release --no-restore
dotnet test *.slnx -c Release --no-build
Write-Host ""
Write-Host "Checking for Unity.Mathematics DLL leak..."
$leaks = Get-ChildItem -Recurse -Filter "Unity.Mathematics*.dll" |
    Where-Object { $_.FullName -notmatch '(\\|/)bin(\\|/)' -and $_.FullName -notmatch '(\\|/)obj(\\|/)' }
if ($leaks) {
    Write-Host "FAIL: Unity.Mathematics DLL found!"
    $leaks | ForEach-Object { Write-Host "  $_" }
    exit 1
}
Write-Host "OK: All tests pass, no DLL leak."
