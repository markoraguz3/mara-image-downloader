$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$buildDirectory = Join-Path $root "build"
$stageDirectory = Join-Path $buildDirectory "installer-stage"
$venvDirectory = Join-Path $buildDirectory "installer-venv"
$embeddedPythonZip = Join-Path $buildDirectory "python-embed.zip"
$embeddedPythonUrl = "https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip"
$installerScript = Join-Path $root "MaraImageDownloader.iss"
$installerOutput = Join-Path $root "dist"
$appVersion = if ($env:MARA_APP_VERSION -match '^\d+\.\d+\.\d+$') {
    $env:MARA_APP_VERSION
} else {
    "1.0.0"
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE`: $FilePath $($Arguments -join ' ')"
    }
}

New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
if (Test-Path -LiteralPath $stageDirectory) {
    Remove-Item -LiteralPath $stageDirectory -Recurse -Force
}
if (Test-Path -LiteralPath $venvDirectory) {
    Remove-Item -LiteralPath $venvDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $stageDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $installerOutput -Force | Out-Null

$pythonCommand = Get-Command python -ErrorAction Stop
$buildPythonExecutable = $pythonCommand.Source
$pythonVersionOutput = & $buildPythonExecutable -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
if ($LASTEXITCODE -ne 0 -or $pythonVersionOutput -ne "3.12") {
    throw "Python 3.12 is required to build this installer. Use the provided GitHub Actions workflow or install Python 3.12."
}

$compiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
if ($compiler) {
    $iscc = $compiler.Source
} else {
    $compilerCandidates = @(
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
        (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
    )
    $iscc = $compilerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $iscc) {
        throw "Inno Setup 6 is required. Install it or build using the provided GitHub Actions workflow."
    }
}

Invoke-CheckedCommand -FilePath $buildPythonExecutable -Arguments @("-m", "venv", $venvDirectory)
$venvPython = Join-Path $venvDirectory "Scripts\python.exe"
Invoke-CheckedCommand -FilePath $venvPython -Arguments @("-m", "pip", "install", "--disable-pip-version-check", "-r", (Join-Path $root "requirements.txt"))

Invoke-WebRequest -Uri $embeddedPythonUrl -OutFile $embeddedPythonZip
$pythonDirectory = Join-Path $stageDirectory "Python"
Expand-Archive -LiteralPath $embeddedPythonZip -DestinationPath $pythonDirectory
$sitePackages = Join-Path $pythonDirectory "Lib\site-packages"
New-Item -ItemType Directory -Path $sitePackages -Force | Out-Null
Invoke-CheckedCommand -FilePath $venvPython -Arguments @("-m", "pip", "install", "--disable-pip-version-check", "--no-warn-script-location", "--target", $sitePackages, "-r", (Join-Path $root "requirements.txt"))

$pythonPathFile = Join-Path $pythonDirectory "python312._pth"
@(
    "python312.zip",
    ".",
    "Lib\site-packages",
    "import site"
) | Set-Content -LiteralPath $pythonPathFile -Encoding Ascii

$browsersDirectory = Join-Path $stageDirectory "browsers"
$env:PLAYWRIGHT_BROWSERS_PATH = $browsersDirectory
$env:PLAYWRIGHT_DOWNLOAD_CONNECTION_TIMEOUT = "600000"
Write-Host "Preuzimam Playwright Chromium za uključenje u instalater..."
$browserInstalled = $false
for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
        Invoke-CheckedCommand -FilePath $venvPython -Arguments @("-m", "playwright", "install", "chromium")
        $browserInstalled = $true
        break
    } catch {
        if ($attempt -eq 3) {
            throw
        }
        Write-Warning "Chromium download failed on attempt $attempt. Retrying in 5 seconds."
        Start-Sleep -Seconds 5
    }
}
if (-not $browserInstalled) {
    throw "Could not download Chromium for the installer."
}

$smokeTest = Join-Path $buildDirectory "installer-smoke-test.py"
@'
import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(headless=True)
        await browser.close()

asyncio.run(main())
'@ | Set-Content -LiteralPath $smokeTest -Encoding Ascii
try {
    Invoke-CheckedCommand -FilePath (Join-Path $pythonDirectory "python.exe") -Arguments @($smokeTest)
} finally {
    Remove-Item -LiteralPath $smokeTest -Force -ErrorAction SilentlyContinue
}

Copy-Item -LiteralPath (Join-Path $root "download_images.py") -Destination $stageDirectory
Copy-Item -LiteralPath (Join-Path $root "Pokreni.bat") -Destination $stageDirectory
Copy-Item -LiteralPath (Join-Path $root "Update-Application.ps1") -Destination $stageDirectory
Copy-Item -LiteralPath (Join-Path $root "Uninstall.bat") -Destination $stageDirectory
Copy-Item -LiteralPath (Join-Path $root "README.md") -Destination $stageDirectory
"$appVersion" | Set-Content -LiteralPath (Join-Path $stageDirectory "app-version.txt") -Encoding Ascii

Push-Location $root
try {
    Invoke-CheckedCommand -FilePath $iscc -Arguments @("/Qp", "/DAppVersion=$appVersion", $installerScript)
} finally {
    Pop-Location
}
Write-Host "Instalater je napravljen: $(Join-Path $installerOutput 'MaraImageDownloaderSetup.exe')"
