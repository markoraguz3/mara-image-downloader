$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms

$applicationDirectory = $PSScriptRoot
$versionFile = Join-Path $applicationDirectory "app-version.txt"
if (-not (Test-Path -LiteralPath $versionFile)) {
    exit 0
}

$currentVersionText = (Get-Content -LiteralPath $versionFile -Raw).Trim()
if ($currentVersionText -notmatch '^\d+\.\d+\.\d+$') {
    [System.Windows.Forms.MessageBox]::Show(
        "Nije moguće provjeriti ažuriranje jer lokalna verzija aplikacije nije ispravna.",
        "MARA Image Downloader",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    exit 1
}
$currentVersion = [version]$currentVersionText

try {
    $release = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/markoraguz3/mara-image-downloader/releases/latest" `
        -Headers @{ "Accept" = "application/vnd.github+json"; "User-Agent" = "MaraImageDownloader" } `
        -TimeoutSec 15
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Provjera ažuriranja nije uspjela:`n$($_.Exception.Message)`n`nPokrećem instaliranu verziju.",
        "MARA Image Downloader",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    exit 1
}

if ($release.tag_name -notmatch '^v?(\d+\.\d+\.\d+)$') {
    [System.Windows.Forms.MessageBox]::Show(
        "Najnoviji release ima neispravan broj verzije: $($release.tag_name)",
        "MARA Image Downloader",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    exit 1
}
$latestVersion = [version]$matches[1]
if ($latestVersion -le $currentVersion) {
    exit 0
}

$installerAsset = $release.assets | Where-Object { $_.name -eq "MaraImageDownloaderSetup.exe" } | Select-Object -First 1
if (-not $installerAsset -or $installerAsset.browser_download_url -notmatch '^https://github\.com/markoraguz3/mara-image-downloader/releases/download/') {
    [System.Windows.Forms.MessageBox]::Show(
        "Release $($release.tag_name) nema očekivani instalater. Pokrećem instaliranu verziju.",
        "MARA Image Downloader",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    exit 1
}

$choice = [System.Windows.Forms.MessageBox]::Show(
    "Dostupna je nova verzija ($latestVersion). Želite li je instalirati sada?",
    "MARA Image Downloader - ažuriranje",
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Information
)
if ($choice -ne [System.Windows.Forms.DialogResult]::Yes) {
    exit 0
}

$installerPath = Join-Path $env:TEMP "MaraImageDownloaderSetup-$latestVersion.exe"
try {
    Invoke-WebRequest -Uri $installerAsset.browser_download_url -OutFile $installerPath -UseBasicParsing -TimeoutSec 120
    $installerInfo = Get-Item -LiteralPath $installerPath
    if ($installerInfo.Length -ne [long]$installerAsset.size) {
        throw "Preuzeti instalater nije potpune veličine."
    }

    $installerProcess = Start-Process `
        -FilePath $installerPath `
        -ArgumentList @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-", "/CLOSEAPPLICATIONS") `
        -Wait `
        -PassThru
    if ($installerProcess.ExitCode -ne 0) {
        throw "Instalater je završio s kodom $($installerProcess.ExitCode)."
    }
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Ažuriranje na verziju $latestVersion nije uspjelo:`n$($_.Exception.Message)`n`nPokrećem instaliranu verziju.",
        "MARA Image Downloader",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
} finally {
    Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
}
