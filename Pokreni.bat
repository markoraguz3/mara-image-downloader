@echo off
setlocal
cd /d "%~dp0"
chcp 65001 >nul
title Preuzimanje slika sa stranice

if not exist "%~dp0Python\python.exe" goto Bootstrap

set "PLAYWRIGHT_BROWSERS_PATH=%~dp0browsers"
set "MARA_DATA_DIR=%LOCALAPPDATA%\MaraImageDownloader"
if not exist "%LOCALAPPDATA%\MaraImageDownloader" mkdir "%LOCALAPPDATA%\MaraImageDownloader"
"%~dp0Python\python.exe" "%~dp0download_images.py"
if errorlevel 1 goto BundledFailure
echo.
echo Program je zavrsio. Pritisnite bilo koju tipku za zatvaranje ovog prozora.
pause >nul
exit /b 0

:BundledFailure
echo.
echo Program nije mogao zavrsiti. Procitajte poruku iznad.
echo Prozor ce se zatvoriti za 15 sekundi.
timeout /t 15 /nobreak >nul
exit /b 1

:Bootstrap
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Pokreni.ps1"
if errorlevel 1 (
    echo.
    echo Program nije mogao zavrsiti. Detalji su sacuvani u program.log.
    echo Prozor ce se zatvoriti za 15 sekundi.
    echo.
    timeout /t 15 /nobreak >nul
) else (
    echo.
    echo Program je zavrsio. Pritisnite bilo koju tipku za zatvaranje ovog prozora.
    pause >nul
)
