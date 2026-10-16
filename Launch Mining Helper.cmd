@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0src\MiningHelper.ps1"
if errorlevel 1 (
  echo.
  echo Mining Helper could not start. Review the message above.
  pause
)
