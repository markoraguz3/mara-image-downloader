$ErrorActionPreference = "Stop"

$localAppData = [System.IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\')
$appDirectory = [System.IO.Path]::GetFullPath(
    (Join-Path $localAppData "MaraImageDownloader")
).TrimEnd('\')
$pythonDirectory = Join-Path $appDirectory "Python"
$browsersDirectory = Join-Path $appDirectory "browsers"
$installer = Join-Path $appDirectory "python-installer.exe"

if (-not $appDirectory.StartsWith(
    "$localAppData\",
    [System.StringComparison]::OrdinalIgnoreCase
) -or (Split-Path -Leaf $appDirectory) -ne "MaraImageDownloader") {
    Write-Host "Sigurnosna provjera putanje nije prosla. Nista nije uklonjeno." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $appDirectory)) {
    Write-Host "Python nije instaliran. Nema sta ukloniti."
    exit 0
}

try {
    $componentsRemoved = $false
    foreach ($component in @($pythonDirectory, $browsersDirectory, $installer)) {
        if (Test-Path -LiteralPath $component) {
            Remove-Item -LiteralPath $component -Recurse -Force
            $componentsRemoved = $true
        }
    }
    if ($componentsRemoved) {
        Write-Host "Uklonjeni su Python i instalirani paketi."
    } else {
        Write-Host "Python i instalirane komponente nisu pronađene."
    }
    Write-Host "Preuzete slike, logovi i programske datoteke nisu dirani."
} catch {
    Write-Host "Nije moguce ukloniti instalirane komponente: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Zatvorite browser i pokusajte ponovo."
    exit 1
}
