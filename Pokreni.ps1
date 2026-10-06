$ErrorActionPreference = "Continue"
$ProgressPreference = "Continue"

$appDirectory = Join-Path $env:LOCALAPPDATA "MaraImageDownloader"
$pythonDirectory = Join-Path $appDirectory "Python"
$python = Join-Path $pythonDirectory "python.exe"
$installer = Join-Path $appDirectory "python-installer.exe"
$browsersDirectory = Join-Path $appDirectory "browsers"
$logFile = Join-Path $PSScriptRoot "program.log"
$transcriptStarted = $false
$pythonVersion = "3.12.10"
$pythonInstallerUrl = if ([Environment]::Is64BitOperatingSystem) {
    "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-amd64.exe"
} else {
    "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion.exe"
}
$currentStep = "pocetno pokretanje"

function Stop-WithMessage([string]$Message) {
    Write-Host ""
    Write-Host $Message -ForegroundColor Red
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
    exit 1
}

try {
    Start-Transcript -Path $logFile -Append | Out-Null
    $transcriptStarted = $true
} catch {
    Write-Host "Upozorenje: nije moguce zapisati log datoteku."
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $consoleEncoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
    [Console]::OutputEncoding = $consoleEncoding
    New-Item -ItemType Directory -Path $appDirectory -Force | Out-Null

    if (-not (Test-Path $python)) {
        $currentStep = "preuzimanje i instalacija Pythona"
        Write-Host "Prvo pokretanje: automatski preuzimam i instaliram Python..."
        Write-Host "Preuzimanje Python instalacije moze potrajati. Molim sacekajte."
        Invoke-WebRequest -Uri $pythonInstallerUrl -OutFile $installer
        Write-Host "Instaliram Python u korisnicki profil..."
        $installProcess = Start-Process -FilePath $installer `
            -ArgumentList "/quiet InstallAllUsers=0 Include_pip=1 Include_launcher=0 Include_test=0 PrependPath=0 TargetDir=`"$pythonDirectory`"" `
            -PassThru
        while (-not $installProcess.HasExited) {
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 2
            $installProcess.Refresh()
        }
        Write-Host ""
        $install = $installProcess
        if ($install.ExitCode -ne 0 -or -not (Test-Path $python)) {
            Stop-WithMessage "Automatska instalacija Pythona nije uspjela (kod $($install.ExitCode))."
        }
        Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
    }

    $env:PLAYWRIGHT_BROWSERS_PATH = $browsersDirectory
    $env:PLAYWRIGHT_DOWNLOAD_CONNECTION_TIMEOUT = "600000"
    $currentStep = "provjera Python instalacije"
    Write-Host "Provjeravam potrebne komponente..."
    & $python -m pip --version *> $null
    if ($LASTEXITCODE -ne 0) {
        & $python -m ensurepip --upgrade
        if ($LASTEXITCODE -ne 0) {
            Stop-WithMessage "Nije bilo moguće pripremiti Pythonov instalacijski alat."
        }
    }

    & $python -c "import playwright" *> $null
    if ($LASTEXITCODE -ne 0) {
        $currentStep = "instalacija potrebne biblioteke"
        Write-Host "Instaliram potrebnu biblioteku..."
        & $python -m pip install --disable-pip-version-check --no-warn-script-location -r (Join-Path $PSScriptRoot "requirements.txt")
        if ($LASTEXITCODE -ne 0) {
            Stop-WithMessage "Instalacija potrebne komponente nije uspjela. Provjerite internet vezu i pokušajte ponovo."
        }
    }

    $currentStep = "instalacija browsera"
    Write-Host "Provjeravam i pripremam browser. Ovo moze potrajati pri prvom pokretanju..."
    $browserInstalled = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        if ($attempt -gt 1) {
            Write-Host "Pokusaj $attempt od 3..."
        }
        & $python -m playwright install chromium
        if ($LASTEXITCODE -eq 0) {
            $browserInstalled = $true
            break
        }
        if ($attempt -lt 3) {
            Write-Host "Preuzimanje nije uspjelo. Pokusavam ponovo za 5 sekundi..."
            Start-Sleep -Seconds 5
        }
    }
    if (-not $browserInstalled) {
        Stop-WithMessage "Preuzimanje browsera nije uspjelo ni nakon 3 pokusaja. Provjerite internet vezu i da li firewall ili proxy blokira cdn.playwright.dev, pa ponovo pokrenite Pokreni.bat."
    }

    $currentStep = "preuzimanje slika"
    Write-Host ""
    & $python (Join-Path $PSScriptRoot "download_images.py")
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage "Program je završio s greškom."
    }
    Write-Host ""
    Write-Host "Gotovo. Preuzete slike nalaze se u folderu downloaded_images."
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
} catch {
    Stop-WithMessage "Greska tokom koraka '$currentStep': $($_.Exception.Message)"
}
