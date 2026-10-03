@echo off
setlocal
cd /d "%~dp0"
chcp 65001 >nul
title Preuzimanje slika sa stranice

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
