$ErrorActionPreference = "Stop"

$localAppData = [System.IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\')
$appDirectory = [System.IO.Path]::GetFullPath(
    (Join-Path $localAppData "MaraImageDownloader")
).TrimEnd('\')

if (-not $appDirectory.StartsWith(
    "$localAppData\",
    [System.StringComparison]::OrdinalIgnoreCase
) -or (Split-Path -Leaf $appDirectory) -ne "MaraImageDownloader") {
    Write-Host "Sigurnosna provjera putanje nije prosla. Nista nije uklonjeno." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $appDirectory)) {
    Write-Host "Python i dodatni browser nisu instalirani. Nema sta ukloniti."
    exit 0
}

try {
    Remove-Item -LiteralPath $appDirectory -Recurse -Force
    Write-Host "Uklonjeni su Python, instalirani paketi i browser."
    Write-Host "Preuzete slike i programske datoteke nisu dirane."
} catch {
    Write-Host "Nije moguce ukloniti instalirane komponente: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Zatvorite browser i pokusajte ponovo."
    exit 1
}
