@echo off
setlocal
set "SCRIPT_DIR=%~dp0"

echo ============================================================
echo   Gitea Windows Runner - Auto Provisioning
echo ============================================================
echo Date/Time: %DATE% %TIME%
echo Executing: %SCRIPT_DIR%install.ps1

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install.ps1"

echo Provisioning script completed at %DATE% %TIME%
exit /b 0
