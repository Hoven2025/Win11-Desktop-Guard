@echo off
if exist "C:\Program Files\PowerShell\7\pwsh.exe" (
    "C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore_wallpapers.ps1" -SaveCurrentAsDefault
    "C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0save_window_layout.ps1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore_wallpapers.ps1" -SaveCurrentAsDefault
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0save_window_layout.ps1"
)
echo.
pause
