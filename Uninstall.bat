@echo off
setlocal
cd /d "%~dp0"
chcp 65001 >nul
title Uklanjanje komponenti programa

if exist "%~dp0unins000.exe" (
    start "" "%~dp0unins000.exe"
    exit /b
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1"
if errorlevel 1 (
    echo.
    echo Uklanjanje nije zavrseno. Procitajte poruku iznad.
)
echo.
pause
