$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$applicationDirectory = $PSScriptRoot
$python = Join-Path $applicationDirectory "Python\python.exe"
$browserDirectory = Join-Path $applicationDirectory "browsers"
if (-not (Test-Path -LiteralPath $python)) {
    $dataDirectory = Join-Path $env:LOCALAPPDATA "MaraImageDownloader"
    $python = Join-Path $dataDirectory "Python\python.exe"
    $browserDirectory = Join-Path $dataDirectory "browsers"
}
$pythonScript = Join-Path $applicationDirectory "download_images.py"
$updater = Join-Path $applicationDirectory "Update-Application.ps1"

if ((Test-Path -LiteralPath $updater) -and (Test-Path -LiteralPath (Join-Path $applicationDirectory "app-version.txt"))) {
    $updateProcess = Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList @("-NoLogo", "-NoProfile", "-STA", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", "`"$updater`"") `
        -WindowStyle Hidden `
        -Wait `
        -PassThru
    if ($updateProcess.ExitCode -eq 10) {
        Start-Process `
            -FilePath "powershell.exe" `
            -ArgumentList @("-NoLogo", "-NoProfile", "-STA", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"") `
            -WindowStyle Hidden
        exit 0
    }
}

if (-not (Test-Path -LiteralPath $python)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Python još nije instaliran. Pokrenite Pokreni.bat da pripremite aplikaciju.",
        "MARA Image Downloader",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    exit 1
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "MARA Image Downloader"
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.ClientSize = New-Object System.Drawing.Size(520, 190)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$instruction = New-Object System.Windows.Forms.Label
$instruction.Text = "Zalijepite link stranice s menijem:"
$instruction.AutoSize = $true
$instruction.Location = New-Object System.Drawing.Point(22, 22)
$form.Controls.Add($instruction)

$urlInput = New-Object System.Windows.Forms.TextBox
$urlInput.Location = New-Object System.Drawing.Point(22, 52)
$urlInput.Size = New-Object System.Drawing.Size(476, 28)
$urlInput.Anchor = "Top,Left,Right"
$form.Controls.Add($urlInput)

$downloadButton = New-Object System.Windows.Forms.Button
$downloadButton.Text = "Preuzmi slike"
$downloadButton.Location = New-Object System.Drawing.Point(22, 94)
$downloadButton.Size = New-Object System.Drawing.Size(145, 34)
$downloadButton.Anchor = "Top,Left"
$form.Controls.Add($downloadButton)
$form.AcceptButton = $downloadButton

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Slike se spremaju u folder MaraImageDownloader."
$statusLabel.AutoSize = $false
$statusLabel.Location = New-Object System.Drawing.Point(22, 143)
$statusLabel.Size = New-Object System.Drawing.Size(476, 24)
$statusLabel.Anchor = "Top,Left,Right"
$form.Controls.Add($statusLabel)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Style = "Marquee"
$progressBar.MarqueeAnimationSpeed = 25
$progressBar.Location = New-Object System.Drawing.Point(180, 101)
$progressBar.Size = New-Object System.Drawing.Size(318, 22)
$progressBar.Visible = $false
$progressBar.Anchor = "Top,Left,Right"
$form.Controls.Add($progressBar)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500
$script:downloadProcess = $null
$script:stdoutTask = $null
$script:stderrTask = $null

$downloadButton.Add_Click({
    $url = $urlInput.Text.Trim()
    $parsedUrl = $null
    if (-not [Uri]::TryCreate($url, [UriKind]::Absolute, [ref]$parsedUrl) -or $parsedUrl.Scheme -notin @("http", "https")) {
        [System.Windows.Forms.MessageBox]::Show(
            "Unesite ispravan link koji počinje sa http:// ili https://.",
            "Neispravan link",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $python
    $quotedScript = '"' + $pythonScript.Replace('"', '\"') + '"'
    $quotedUrl = '"' + $url.Replace('"', '\"') + '"'
    $startInfo.Arguments = "-u $quotedScript $quotedUrl"
    $startInfo.WorkingDirectory = $applicationDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $startInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $startInfo.EnvironmentVariables["PLAYWRIGHT_BROWSERS_PATH"] = $browserDirectory
    $startInfo.EnvironmentVariables["MARA_DATA_DIR"] = Join-Path $env:LOCALAPPDATA "MaraImageDownloader"

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw "Downloader se nije mogao pokrenuti."
        }
        $script:downloadProcess = $process
        $script:stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $script:stderrTask = $process.StandardError.ReadToEndAsync()
        $downloadButton.Enabled = $false
        $urlInput.Enabled = $false
        $progressBar.Visible = $true
        $statusLabel.Text = "Preuzimanje je u toku. Možete riješiti CAPTCHA u otvorenom browseru."
        $timer.Start()
    } catch {
        $process.Dispose()
        [System.Windows.Forms.MessageBox]::Show(
            "Downloader se nije mogao pokrenuti:`n$($_.Exception.Message)",
            "Greška",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$timer.Add_Tick({
    if (-not $script:downloadProcess.HasExited) {
        return
    }

    $timer.Stop()
    $downloadOutput = $script:stdoutTask.Result
    $errorOutput = $script:stderrTask.Result
    $exitCode = $script:downloadProcess.ExitCode
    $script:downloadProcess.Dispose()
    $script:downloadProcess = $null
    $progressBar.Visible = $false
    $downloadButton.Enabled = $true
    $urlInput.Enabled = $true

    if ($exitCode -eq 0) {
        $summary = [regex]::Match($downloadOutput, "Gotovo: preuzeto \d+ od \d+ slika\.")
        $statusLabel.Text = if ($summary.Success) { $summary.Value } else { "Preuzimanje je završeno." }
        if ($downloadOutput.Contains("Nisu pronađene slike za preuzimanje.")) {
            [System.Windows.Forms.MessageBox]::Show(
                "Na stranici nisu pronađene odgovarajuće slike proizvoda.",
                "Nema slika",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        }
    } else {
        $details = if ($errorOutput.Trim()) { $errorOutput.Trim() } else { $downloadOutput.Trim() }
        if ($details.Length -gt 1800) {
            $details = $details.Substring($details.Length - 1800)
        }
        $statusLabel.Text = "Preuzimanje nije uspjelo."
        [System.Windows.Forms.MessageBox]::Show(
            "Preuzimanje nije uspjelo:`n$details",
            "Greška",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$form.Add_Shown({ $urlInput.Focus() })
$form.Add_FormClosing({
    if ($script:downloadProcess -and -not $script:downloadProcess.HasExited) {
        $choice = [System.Windows.Forms.MessageBox]::Show(
            "Preuzimanje je još u toku. Želite li zatvoriti prozor i prekinuti ga?",
            "Preuzimanje u toku",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($choice -ne [System.Windows.Forms.DialogResult]::Yes) {
            $_.Cancel = $true
            return
        }
        $script:downloadProcess.Kill()
        $script:downloadProcess.Dispose()
    }
})

[void]$form.ShowDialog()
